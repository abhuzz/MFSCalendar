//
//  CalendarViewController.swift
//  MFSCalendar
//
//  Created by David Dai on 2017/4/14.
//  Copyright © 2017年 David. All rights reserved.
//

import UIKit
import DZNEmptyDataSet
import FSCalendar
import Crashlytics
import SnapKit
import XLPagerTabStrip

class customCalendarCell: UITableViewCell {

    @IBOutlet weak var ClassName: UILabel!

    @IBOutlet weak var PeriodNumber: UILabel!

    @IBOutlet weak var RoomNumber: UILabel!

    @IBOutlet weak var PeriodTime: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}

class customEventCell: UITableViewCell {

    @IBOutlet weak var ClassName: UILabel!

    @IBOutlet weak var PeriodNumber: UILabel!

    @IBOutlet weak var RoomNumber: UILabel!

    @IBOutlet weak var PeriodTime: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}

class CalendarViewController: TwitterPagerTabStripViewController, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate, UIGestureRecognizerDelegate {

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    @IBOutlet weak var backButton: UIBarButtonItem!

    @IBOutlet weak var calendarView: FSCalendar!

    @IBOutlet weak var calendarHeightConstraint: NSLayoutConstraint!

    var numberOfRolls: Int? = 6

    let formatter = DateFormatter()
    var dayOfSchool: String? = nil
    var screenSize = UIScreen.main.bounds.size
    
    let classViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier :"timeTableViewController") as! ADay
    let eventViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier :"eventViewController") as! eventViewController
    let homeworkViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier :"homeworkViewController") as! homeworkViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.backButton.title = "Collapse"
        addScopeGesture()
        self.calendarView.select(Date())
        
        dataFetching()
        eventDataFetching()
        homeworkDataFetching()
        
        self.calendarView.delegate = self
        self.calendarView.dataSource = self
    }
    
    func addScopeGesture() {
        let viewArray = [self, classViewController, eventViewController, homeworkViewController]
        for viewController in viewArray {
            let scopeGesture: UIPanGestureRecognizer = {
                [unowned self] in
                let panGesture = UIPanGestureRecognizer(target: self.calendarView, action: #selector(self.calendarView.handleScopeGesture(_:)))
                panGesture.delegate = self
                panGesture.minimumNumberOfTouches = 1
                panGesture.maximumNumberOfTouches = 2
                return panGesture
                }()
            viewController.view.addGestureRecognizer(scopeGesture)
            
            if let thisViewController = viewController as? ADay {
                thisViewController.tableView.panGestureRecognizer.require(toFail: scopeGesture)
            } else if let thisViewController = viewController as? eventViewController {
                thisViewController.eventView.panGestureRecognizer.require(toFail: scopeGesture)
            } else if let thisViewController = viewController as? homeworkViewController {
                thisViewController.homeworkTable.panGestureRecognizer.require(toFail: scopeGesture)
            }
        }
    }
    
    override func viewControllers(for pagerTabStripController: PagerTabStripViewController) -> [UIViewController] {
        return [classViewController, homeworkViewController, eventViewController]
    }

    @IBAction func expandButton(_ sender: Any) {
        if self.calendarView.scope == .month {
            self.backButton.title = "Expand"
            self.calendarView.setScope(.week, animated: true)
        } else {
            self.backButton.title = "Collapse"
            self.calendarView.setScope(.month, animated: true)
        }

    }

    @IBAction func backToToday(_ sender: Any) {
        self.calendarView.select(Date())
        let _ = self.checkDate(checkDate: Date())
        self.dataFetching()
        self.eventDataFetching()
        self.homeworkDataFetching()
//        Crashlytics.sharedInstance().crash()
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let shouldBegin =
            ((classViewController.tableView.contentOffset.y <= -classViewController.tableView.contentInset.top) ||
            (eventViewController.eventView.contentOffset.y <= -eventViewController.eventView.contentInset.top)) || (homeworkViewController.homeworkTable.contentOffset.y <= -homeworkViewController.homeworkTable.contentInset.top)
        if shouldBegin {
            let velocity = (gestureRecognizer as! UIPanGestureRecognizer).velocity(in: self.view)
//            往上拉->日历拉长。
            switch self.calendarView.scope {
            case .month:
                return velocity.y < 0
            case .week:
                return velocity.y > 0
            }
        }
        return shouldBegin
    }

    func checkDate(checkDate: Date) -> String {
        let plistPath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.dwei.MFSCalendar")!.path
        let path = plistPath.appending("/Day.plist")
        let dayDict = NSDictionary(contentsOfFile: path)
        self.formatter.dateFormat = "yyyyMMdd"
        let checkDate = self.formatter.string(from: checkDate)

        let day = dayDict?[checkDate] as? String ?? "No School"

        return day
    }
    
    func dataFetching() {
        guard let checkDate = self.calendarView.selectedDates.first else {
            return
        }
        
        self.dayOfSchool = self.checkDate(checkDate: checkDate)
        if self.dayOfSchool != "No School" {
            classViewController.daySelected = self.dayOfSchool
        } else {
            classViewController.daySelected = nil
        }
        
        DispatchQueue.main.async {
            self.classViewController.dataFetching()
        }
    }
    
    func eventDataFetching() {
        let selectedDate = self.calendarView.selectedDates.first
        eventViewController.selectedDate = selectedDate
        eventViewController.eventDataFetching()
    }
    
    func homeworkDataFetching() {
        let selectedDate = self.calendarView.selectedDates.first
        homeworkViewController.daySelected = selectedDate
        homeworkViewController.filter = 1
        
        DispatchQueue.global().async {
            self.homeworkViewController.getHomework()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()

    }
}




extension CalendarViewController: FSCalendarDelegate, FSCalendarDataSource {
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        if #available(iOS 10.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        }
        
        DispatchQueue.main.async {
            self.reloadPagerTabStripView()
        }
        
        let _ = self.checkDate(checkDate: date)
        dataFetching()
        eventDataFetching()
        homeworkDataFetching()
    }

    func calendar(_ calendar: FSCalendar, subtitleFor date: Date) -> String? {
        let day = checkDate(checkDate: date)
        if day == "No School" {
            return nil
        } else {
            return day
        }
    }
    
    func calendar(_ calendar: FSCalendar, boundingRectWillChange bounds: CGRect, animated: Bool) {
        self.calendarHeightConstraint.constant = bounds.height
        if self.calendarView.scope == .month {
            self.backButton.title = "Collapse"
        } else {
            self.backButton.title = "Expand"
        }
        
        self.view.layoutIfNeeded()
        //self.classView.frame.size.height = self.bottomScrollView.frame.height
    }

}

class eventViewController: UIViewController, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate, IndicatorInfoProvider {
    
    @IBOutlet var eventView: UITableView!
    let formatter = DateFormatter()
    var listEvents: NSMutableArray = []
    var selectedDate: Date? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        let attr = [NSFontAttributeName: UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline)]
        let str = "There is no event on this day."
        self.eventView.separatorStyle = .none
        
        return NSAttributedString(string: str, attributes: attr)
    }
    
    func image(forEmptyDataSet scrollView: UIScrollView!) -> UIImage! {
        let image = UIImage(named: "School_building.png")?.imageResize(sizeChange: CGSize(width: 95, height: 95))
        
        return image
    }
    
    func eventDataFetching() {
        self.eventView.separatorStyle = .singleLine
        let plistPath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.dwei.MFSCalendar")!.path
        let fileName = "/Events.plist"
        let path = plistPath.appending(fileName)
        let eventData = NSMutableDictionary(contentsOfFile: path)
        guard let SelectedDate = selectedDate else {
            print("No Date")
            return
        }
        self.formatter.dateFormat = "yyyyMMdd"
        let eventDate = formatter.string(from: SelectedDate)
        guard let events = eventData?[eventDate] as? NSMutableArray else {
            self.listEvents = []
            self.eventView.reloadData(with: .automatic)
            self.eventView.reloadData()
            return
        }
        self.listEvents = events
        self.eventView.reloadData(with: .automatic)
        self.eventView.reloadData()
    }
    
    func indicatorInfo(for pagerTabStripController: PagerTabStripViewController) -> IndicatorInfo {
        return IndicatorInfo(title: "Events")
    }
}

extension eventViewController: UITableViewDelegate, UITableViewDataSource {
    
    //    the number of the cell
    func tableView(_ tableView: UITableView, numberOfRowsInSection selection: Int) -> Int {
        return self.listEvents.count
    }
    
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "eventTable", for: indexPath as IndexPath) as? customEventCell
        let row = indexPath.row
        let rowDict = self.listEvents[row] as! Dictionary<String, Any?>
        let summary = rowDict["summary"] as? String
        cell?.ClassName.text = summary
        let letter = summary?.substring(to: (summary?.index(after: (summary?.startIndex)!))!)
        cell?.PeriodNumber.text = letter!
        if rowDict["location"] != nil {
            let location = rowDict["location"] as! String
            if location.hasSuffix("place fields") || location.hasSuffix("Place Fields") {
                cell?.RoomNumber.text = nil
            } else {
                cell?.RoomNumber.text = "At: " + location
            }
        }
        
        cell?.PeriodTime.text = EventView().getTimeInterval(rowDict: rowDict)
        return cell!
    }
}

