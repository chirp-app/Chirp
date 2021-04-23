//
//  CalendarViewController.swift
//  Messenger
//
//  Created by Evan ORourke on 4/22/21.
//

import Foundation
import FSCalendar
import UIKit

class CalendarViewController: UIViewController, FSCalendarDelegate {
    
    var calendar = FSCalendar()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        calendar.delegate = self
        // Do any additional setup after loading the view.
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        calendar.frame = CGRect(x: 0,
                                y: 100,
                                width: view.frame.size.width,
                                height: view.frame.size.width)
        view.addSubview(calendar)
    }
    
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE MM-dd-YYYY at h:mm a"
        let dateString = formatter.string(from: date)
        
        print("\(dateString)")
    }


}
