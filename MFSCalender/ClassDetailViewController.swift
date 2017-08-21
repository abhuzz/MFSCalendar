//
//  ClassDetailViewController.swift
//  MFSCalendar
//
//  Created by David Dai on 2017/6/22.
//  Copyright © 2017年 David. All rights reserved.
//

import UIKit
import XLPagerTabStrip
import SwiftMessages
import SwiftyJSON
import DGElasticPullToRefresh
import Alamofire
import M13ProgressSuite
import SnapKit

class classDetailViewController: UITableViewController, UIDocumentInteractionControllerDelegate {
    
    var classObject: NSDictionary? = nil
    var avaliableInformation = [String]()
    
    var syllabusList = [NSDictionary]()
    
    @IBOutlet weak var teacherName: UILabel!
    @IBOutlet weak var roomNumber: UILabel!
    
    @IBOutlet var basicInformationView: UIView!
    @IBOutlet var classDetailTable: UITableView!
    
    @IBOutlet weak var profileImageView: UIImageView!
    
    let semaphore = DispatchSemaphore.init(value: 0)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.global().async {
            self.getTheClassToPresent()
            self.loadContent()
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let loadingview = DGElasticPullToRefreshLoadingViewCircle()
        loadingview.tintColor = UIColor.white
        classDetailTable.dg_addPullToRefreshWithActionHandler({ [weak self] () -> Void in
            self?.refreshContent()
            //            self?.semaphore.wait()
            self?.tableView.dg_stopLoading()
            }, loadingView: loadingview)
        classDetailTable.dg_setPullToRefreshFillColor(UIColor(hexString: 0xFF7E79))
        classDetailTable.dg_setPullToRefreshBackgroundColor(tableView.backgroundColor!)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        DispatchQueue.global().async {
            self.refreshContent()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        classDetailTable.dg_removePullToRefresh()
    }
    
    func getTheClassToPresent() {
        let classPath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.dwei.MFSCalendar")!.path
        let path = classPath.appending("/CourseList.plist")
        guard let classList = NSArray(contentsOfFile: path) else {
            return
        }
        
        guard let index = userDefaults?.integer(forKey: "indexForCourseToPresent") else {
            return
        }
        
        classObject = classList[index] as? NSDictionary
        
        print(classObject as Any!)
    }
    
    func loadContent() {
        if (!teacherName.text!.isEmpty || !roomNumber.text!.isEmpty) && !avaliableInformation.contains("Basic") {
            //            其中一个不为空,且目前还没有这一项时
            avaliableInformation.append("Basic")
        }
        
        if let sectionId = classObject?["leadsectionid"] as? Int {
            let path = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.dwei.MFSCalendar")!.path
            let fileManager = FileManager.default
            
            let syllabusPath = path.appending("/\(sectionId)_syllabus.plist")
            
            if fileManager.fileExists(atPath: syllabusPath) {
                self.syllabusList = NSArray(contentsOfFile: syllabusPath) as! [NSDictionary]
            }
            
            if self.syllabusList.count > 0 && !self.avaliableInformation.contains("Syllabus") {
                
                self.avaliableInformation.append("Syllabus")
            }
        }
        
        DispatchQueue.main.async {
            self.classDetailTable.reloadData()
        }
    }
    
    func refreshContent() {
        
        roomNumber.text = classObject?["roomNumber"] as? String ?? ""
        teacherName.text = classObject?["teacherName"] as? String ?? ""
        
        if let sectionId = classObject?["leadsectionid"] as? Int {
            DispatchQueue.main.async {
                self.navigationController?.showProgress()
                self.navigationController?.setIndeterminate(true)
                UIApplication.shared.isNetworkActivityIndicatorVisible = true
            }
            
            let sectionIdString = String(describing: sectionId)
            
            provider.request(.getPossibleContent(sectionId: sectionIdString), completion: {
                (result) in
                switch result {
                case let .success(response):
                    do {
                        guard let json = try JSONSerialization.jsonObject(with: response.data, options: .allowFragments) as? Array<Dictionary<String, Any?>> else {
                            presentErrorMessage(presentMessage: "Internal error: Incorrect data format", layout: .StatusLine)
                            return
                        }
                        
                    } catch {
                        presentErrorMessage(presentMessage: error.localizedDescription, layout: .StatusLine)
                    }
                case let .failure(error):
                    presentErrorMessage(presentMessage: error.localizedDescription, layout: .StatusLine)
                }
            })
            
            if self.syllabusList.count > 0 && !self.avaliableInformation.contains("Syllabus") {
                
                self.avaliableInformation.append("Syllabus")
                DispatchQueue.main.async {
                    self.classDetailTable.reloadData()
                }
            } else {
                DispatchQueue.main.async {
                    self.classDetailTable.reloadData(with: .automatic)
                }
            }
            
            DispatchQueue.main.async {
                self.classDetailTable.reloadData(with: .automatic)
                self.navigationController?.cancelProgress()
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
        }
    }
}

extension classDetailViewController: IndicatorInfoProvider {
    func indicatorInfo(for pagerTabStripController: PagerTabStripViewController) -> IndicatorInfo {
        return IndicatorInfo(title: "OVERVIEW") 
    }
}

extension classDetailViewController {
//    Tableview delegate & datasource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return avaliableInformation.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch avaliableInformation[section] {
        case "Basic":
            return 1
        case "Syllabus":
            return syllabusList.count
        default:
            return 1
        }
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if avaliableInformation[indexPath.section] == "Basic" {
            return 130
        }
        
        return UITableViewAutomaticDimension
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return avaliableInformation[section]
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = classDetailTable.dequeueReusableCell(withIdentifier: "classOverviewTable", for: indexPath)
        let section = indexPath.section
        
        switch avaliableInformation[section] {
        case "Basic":
            let sectionId = classObject?["leadsectionid"] as! Int
            let photoPath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.dwei.MFSCalendar")!.path
            let path = photoPath.appending("/\(sectionId)_profile.png")
            profileImageView.image = UIImage(contentsOfFile: path)
            profileImageView.contentMode = UIViewContentMode.scaleAspectFill
            profileImageView.clipsToBounds = true
            
            cell.selectionStyle = .none
            
            basicInformationView.frame = CGRect(x: 0, y: 1, width: cell.frame.size.width, height: cell.frame.size.height - 2)
            cell.addSubview(basicInformationView)
            cell.layoutSubviews()
        case "Syllabus":
            let syllabusCell = classDetailTable.dequeueReusableCell(withIdentifier: "syllabusCell", for: indexPath) as! syllabusView
            let syllabusItem = syllabusList[indexPath.row]
            
            var htmlString = syllabusItem["Description"] as? String ?? ""
            
            if !htmlString.isEmpty {
                htmlString = "<html>" +
                    "<head>" +
                    "<style>" +
                    "body {" +
                    "font-family: 'Helvetica';" +
                    "font-size:15px;" +
                    "text-decoration:none;" +
                    "}" +
                    "</style>" +
                    "</head>" +
                    "<body>" +
                        htmlString +
                "</body></head></html>"
            }
            let htmlData = NSString(string: htmlString).data(using: String.Encoding.unicode.rawValue)
            
            if let attributedString = try? NSAttributedString(data: htmlData!, options: [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType], documentAttributes: nil) {
                syllabusCell.syllabusDescription.attributedText = attributedString
            } else {
                syllabusCell.syllabusDescription.text = htmlString
            }
            
            syllabusCell.attachmentQueryString = syllabusItem["AttachmentQueryString"] as? String ?? ""
            syllabusCell.attachmentFileName = syllabusItem["Attachment"] as? String ?? ""
            
            syllabusCell.title.setTitle(syllabusItem["ShortDescription"] as? String ?? "", for: .normal)
            
            syllabusCell.syllabusDescription.isScrollEnabled = true
            
            if syllabusCell.syllabusDescription.contentSize.height >= 200 {
                syllabusCell.syllabusDescription.snp.makeConstraints({ (make) in
                    syllabusCell.heightConstrant = make.height.equalTo(200).constraint
                })
                
                syllabusCell.showMoreView.isHidden = false
            } else {
                syllabusCell.showMoreView.isHidden = true
                syllabusCell.sizeToFit()
            }
            
            syllabusCell.syllabusDescription.isScrollEnabled = false
            
            syllabusCell.selectionStyle = .none
            //syllabusCell.parentViewController = self
            
            return syllabusCell
        default:
            break
        }
        
        return cell
    }
}

extension classDetailViewController {
    func getProfilePhotoLink(sectionId: String) -> String {
        guard loginAuthentication().success else {
            return ""
        }
        let urlString = "https://mfriends.myschoolapp.com/api/media/sectionmediaget/\(sectionId)/?format=json&contentId=31&editMode=false&active=true&future=false&expired=false&contextLabelId=2"
        let url = URL(string: urlString)
        //create request.
        let request3 = URLRequest(url: url!)
        let semaphore = DispatchSemaphore(value: 0)
        
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        var photolink = ""
        
        let session = URLSession.init(configuration: config)
        
        let dataTask = session.dataTask(with: request3, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) -> Void in
            if error == nil {
                let json = JSON(data: data!)
                if let filePath = json[0]["FilenameUrl"].string {
                    photolink = "https:" + filePath
                } else {
                    NSLog("File path not found. Error code: 13")
                }
            } else {
                DispatchQueue.main.async {
                    let presentMessage = (error?.localizedDescription)! + " Please check your internet connection."
                    let view = MessageView.viewFromNib(layout: .CardView)
                    view.configureTheme(.error)
                    let icon = "😱"
                    view.configureContent(title: "Error!", body: presentMessage, iconText: icon)
                    view.button?.isHidden = true
                    let config = SwiftMessages.Config()
                    SwiftMessages.show(config: config, view: view)
                }
            }
            semaphore.signal()
        })
        //使用resume方法启动任务
        dataTask.resume()
        semaphore.wait()
        return photolink
    }
    
    func getProfilePhoto(photoLink: String, sectionId:String) {
        let url = URL(string: photoLink)
        //create request.
        let request3 = URLRequest(url: url!)
        let semaphore = DispatchSemaphore(value: 0)
        
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        
        let session = URLSession.init(configuration: config)
        
        let downloadTask = session.downloadTask(with: request3, completionHandler: { (location: URL?, response: URLResponse?, error: Error?) -> Void in
            if error == nil {
                //Temp location:
                print("location:\(String(describing: location))")
                let locationPath = location!.path
                //Copy to User Directory
                let photoPath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.dwei.MFSCalendar")!.path
                let path = photoPath.appending("/\(sectionId)_profile.png")
                //Init FileManager
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: path) {
                    do {
                        try fileManager.removeItem(atPath: path)
                    } catch {
                        NSLog("File does not exist! (Which is impossible)")
                    }
                }
                try! fileManager.moveItem(atPath: locationPath, toPath: path)
                print("new location:\(path)")
            } else {
                DispatchQueue.main.async {
                    let presentMessage = (error?.localizedDescription)! + " Please check your internet connection."
                    let view = MessageView.viewFromNib(layout: .CardView)
                    view.configureTheme(.error)
                    let icon = "😱"
                    view.configureContent(title: "Error!", body: presentMessage, iconText: icon)
                    view.button?.isHidden = true
                    let config = SwiftMessages.Config()
                    SwiftMessages.show(config: config, view: view)
                }
            }
            semaphore.signal()
        })
        //使用resume方法启动任务
        downloadTask.resume()
        semaphore.wait()
    }
    
    func getContent(sectionId: String) {
        guard loginAuthentication().success else {
            return
        }
        
        let urlString = "https://mfriends.myschoolapp.com/api/syllabus/forsection/\(sectionId)/?format=json&active=true&future=false&expired=false"
        let url = URL(string: urlString)
        //create request.
        let request3 = URLRequest(url: url!)
        let semaphore = DispatchSemaphore(value: 0)
        
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        
        let session = URLSession.init(configuration: config)
        
        let dataTask = session.dataTask(with: request3, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) -> Void in
            if error == nil {
                guard let json = JSON(data: data!).arrayObject as? [NSDictionary] else {
                    semaphore.signal()
                    return
                }
                
                var arrayToWrite = [NSDictionary]()
                
                for items in json {
                    let dictToAdd: NSMutableDictionary = [:]
                    dictToAdd["Description"] = items["Description"]
                    dictToAdd["ShortDescription"] = items["ShortDescription"]
                    dictToAdd["Attachment"] = items["Attachment"]
                    dictToAdd["AttachmentQueryString"] = items["AttachmentQueryString"]
                    arrayToWrite.append(dictToAdd)
                }
                
                let photoPath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.dwei.MFSCalendar")!.path
                let path = photoPath.appending("/\(sectionId)_syllabus.plist")
                NSArray(array: arrayToWrite).write(toFile: path, atomically: true)
            } else {
                DispatchQueue.main.async {
                    let presentMessage = (error?.localizedDescription)! + " Please check your internet connection."
                    let view = MessageView.viewFromNib(layout: .CardView)
                    view.configureTheme(.error)
                    let icon = "😱"
                    view.configureContent(title: "Error!", body: presentMessage, iconText: icon)
                    view.button?.isHidden = true
                    let config = SwiftMessages.Config()
                    SwiftMessages.show(config: config, view: view)
                }
            }
            semaphore.signal()
        })
        //使用resume方法启动任务
        dataTask.resume()
        semaphore.wait()
    }
    
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
}

class syllabusView: UITableViewCell {
    @IBOutlet weak var title: UIButton!
    @IBOutlet var syllabusDescription: UITextView!
    var attachmentQueryString: String? = nil
    var attachmentFileName: String? = nil
    var heightConstrant: Constraint? = nil
    
    @IBOutlet var showMoreView: UIView!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    @IBAction func showMoreButtonClicked(_ sender: Any) {
        let thisParentViewController = parentViewController as? classDetailViewController
        DispatchQueue.main.async {
            thisParentViewController?.tableView.beginUpdates()
            self.heightConstrant?.deactivate()
            self.syllabusDescription.sizeToFit()
            self.showMoreView.isHidden = true
            self.layoutIfNeeded()
            thisParentViewController?.tableView.endUpdates()
        }
    }
    
    
    @IBAction func titleClicked(_ sender: Any) {
        DispatchQueue.main.async {
            self.parentViewController!.navigationController?.showProgress()
            self.parentViewController!.navigationController?.setIndeterminate(true)
        }
        
        guard !self.attachmentFileName!.isEmpty else {
            presentMessage(message: "There is no attachment.")
            self.parentViewController!.navigationController?.cancelProgress()
            return
        }
        
        let path = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.dwei.MFSCalendar")!.path
        let attachmentPath = path + "/" + self.attachmentFileName!
        NSLog("AttachmentPath: \(attachmentPath)")
        //Init FileManager
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: attachmentPath) {
//          Open the existing attachment.
            NSLog("Attempting to open file: \(self.attachmentFileName!)")
            openFile(fileUrl: URL(fileURLWithPath: attachmentPath))
            return
        }
        
        guard !(attachmentQueryString?.isEmpty)! else {
            presentMessage(message: "The attachment cannot be found.")
            self.parentViewController!.navigationController?.cancelProgress()
            return
        }
        
        guard loginAuthentication().success else {
            return
        }
        
        let url = "https://mfriends.myschoolapp.com/app/utilities/FileDownload.ashx?" + attachmentQueryString!
        //        create request.
//        Alamofire Test.
        let destination: DownloadRequest.DownloadFileDestination = { _, _ in
            let fileURL = URL(fileURLWithPath: attachmentPath)
            print(fileURL)
            
            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }

        
        Alamofire.download(url, to: destination).response { response in
//            print(response)
            
            if response.error == nil {
                
                NSLog("Attempting to open file: \(self.attachmentFileName!)")
                self.openFile(fileUrl: URL(fileURLWithPath: attachmentPath))
            } else {
                DispatchQueue.main.async {
                    self.parentViewController!.navigationController?.cancelProgress()
                    let message = response.error!.localizedDescription + " Please check your internet connection."
                    self.presentMessage(message: message)
                }
            }
        }
    }
    
    func openFile(fileUrl: URL) {
        let documentController = UIDocumentInteractionController.init(url: fileUrl)
        
        
        documentController.delegate = parentViewController! as? UIDocumentInteractionControllerDelegate
        
        DispatchQueue.main.async {
            self.parentViewController!.navigationController?.cancelProgress()
            documentController.presentPreview(animated: true)
        }
        
    }
    
    func presentMessage(message: String) {
        let view = MessageView.viewFromNib(layout: .CardView)
        view.configureTheme(.error)
        let icon = "😱"
        view.configureContent(title: "Error!", body: message, iconText: icon)
        view.button?.isHidden = true
        let config = SwiftMessages.Config()
        SwiftMessages.show(config: config, view: view)
    }
}
