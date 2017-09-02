//
//  PublicFunctions.swift
//  MFSCalendar
//
//  Created by David Dai on 2017/8/5.
//  Copyright © 2017年 David. All rights reserved.
//

import Foundation
import SwiftMessages

func areEqual<T:Equatable>(type: T.Type, a: Any?, b: Any?) -> Bool? {
    guard let a = a as? T, let b = b as? T else {
        return nil
    }

    return a == b
}

public func loginAuthentication() -> (success: Bool, token: String, userId: String) {

    guard let usernameText = userDefaults?.string(forKey: "username") else {
        return (false, "Username Not Found", "")
    }
    guard let passwordText = userDefaults?.string(forKey: "password") else {
        return (false, "Password Not Found", "")
    }

    var token: String? = ""
    var userID: String? = ""
    var success: Bool = false

    if let loginDate = userDefaults?.object(forKey: "loginTime") as? Date {
        let now = Date()
        let timeInterval = Int(now.timeIntervalSince(loginDate))
        if timeInterval < 1200 {
            success = true
            token = userDefaults?.string(forKey: "token")
            userID = userDefaults?.string(forKey: "userID")

            addLoginCookie(token: token!)

            return (success, token!, userID!)
        }
    }

    guard let usernameTextUrlEscaped = usernameText.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
        return (false, "Cannot convert to url string", "")
    }

    guard let passwordTextUrlEscaped = passwordText.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
        return (false, "Cannot convert to url string", "")
    }

    let accountCheckURL = "https://mfriends.myschoolapp.com/api/authentication/login/?username=" + usernameTextUrlEscaped + "&password=" + passwordTextUrlEscaped + "&format=json"
    let url = NSURL(string: accountCheckURL)
    let request = URLRequest(url: url! as URL)

    let config = URLSessionConfiguration.default
    config.requestCachePolicy = .reloadIgnoringLocalCacheData
    config.urlCache = nil

    let session = URLSession.init(configuration: config)

    let semaphore = DispatchSemaphore.init(value: 0)
    let task: URLSessionDataTask = session.dataTask(with: request, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) -> Void in
        if error == nil {
            do {
                let resDict = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! NSDictionary
                print(resDict)
                if resDict["Error"] != nil {
                    //                        When error occured. Like the username or password is not correct.
                    print("Login Error!")
                    if (resDict["ErrorType"] as! String) == "UNAUTHORIZED_ACCESS" {
                        token = "Incorrect password"
                    }
                } else {
                    //                      When authentication is success.
                    success = true
                    token = resDict["Token"] as? String
                    userID = String(describing: resDict["UserId"]!)
                    userDefaults?.set(token, forKey: "token")
                    userDefaults?.set(userID, forKey: "userID")
                    userDefaults?.set(Date(), forKey: "loginTime")
                }
            } catch {
                NSLog("Data parsing failed")
                DispatchQueue.main.async {
                    token = "Data parsing failed"
                }
            }
        } else {
            DispatchQueue.main.async {
                let presentMessage = (error?.localizedDescription)! + " Please check your internet connection."
                token = presentMessage
            }

        }
        semaphore.signal()

    })

    task.resume()
    semaphore.wait()

    if success {
        addLoginCookie(token: token!)
    }

    return (success, token!, userID!)
}

public func addLoginCookie(token: String) {
    let cookieProps: [HTTPCookiePropertyKey: Any] = [
        HTTPCookiePropertyKey.domain: "mfriends.myschoolapp.com",
        HTTPCookiePropertyKey.path: "/",
        HTTPCookiePropertyKey.name: "t",
        HTTPCookiePropertyKey.value: token
    ]

    if let cookie = HTTPCookie(properties: cookieProps) {
        HTTPCookieStorage.shared.setCookie(cookie)
    }

    let cookieProps2: [HTTPCookiePropertyKey: Any] = [
        HTTPCookiePropertyKey.domain: "mfriends.myschoolapp.com",
        HTTPCookiePropertyKey.path: "/",
        HTTPCookiePropertyKey.name: "bridge",
        HTTPCookiePropertyKey.value: "action=create&src=webapp&xdb=true"
    ]

    if let cookie = HTTPCookie(properties: cookieProps2) {
        HTTPCookieStorage.shared.setCookie(cookie)
    }
}

public func presentErrorMessage(presentMessage: String, layout: MessageView.Layout) {
    let view = MessageView.viewFromNib(layout: layout)
    view.configureTheme(.error)
    let icon = "😱"
    view.configureContent(title: "Error!", body: presentMessage, iconText: icon)
    view.button?.isHidden = true
    let config = SwiftMessages.Config()
    SwiftMessages.show(config: config, view: view)
}

class classView {
    func getTheClassToPresent() -> Dictionary<String, Any>? {
        let classPath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.dwei.MFSCalendar")!.path
        let path = classPath.appending("/CourseList.plist")
        guard let classList = NSArray(contentsOfFile: path) as? Array<Dictionary<String, Any>> else {
            return nil
        }

        guard let index = userDefaults?.integer(forKey: "indexForCourseToPresent") else {
            return nil
        }

        if let thisClassObject = classList.filter({ $0["index"] as! Int == index }).first {
            return thisClassObject
        }

        return nil
    }
}

class EventView {
    func getTimeInterval(rowDict: [String: Any?]) -> String {
        let formatter = DateFormatter()
        if (rowDict["isAllDay"] as! Int) == 1 {
            return "All Day"
        } else {
            let tEnd = String(describing: (rowDict["tEnd"] as! Int))
            if (rowDict["tEnd"] as! Int) > 99999 {
                formatter.dateFormat = "HHmmss"
            } else {
                formatter.dateFormat = "Hmmss"
            }
            let timeEnd = formatter.date(from: tEnd)
            let tStart = String(describing: (rowDict["tStart"] as! Int))
            if (rowDict["tStart"] as! Int) > 99999 {
                formatter.dateFormat = "HHmmss"
            } else {
                formatter.dateFormat = "Hmmss"
            }
            let timeStart = formatter.date(from: tStart)
            formatter.dateFormat = "h:mm a"
            let startString = formatter.string(from: timeStart!)
            let endString = formatter.string(from: timeEnd!)
            return startString + " - " + endString
        }
    }
}

