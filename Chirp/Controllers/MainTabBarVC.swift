//
//  MainTabBarVC.swift
//  Messenger
//
//  Created by Evan ORourke on 4/19/21.
//

import Foundation

import UIKit

class MainTabBarVC: UITabBarController {
    
    internal static let tabs = ["Chat", "Calendar", "Profile"]
    
    init() {
        super.init(nibName: nil, bundle: nil)

        let chatNavC = UINavigationController(rootViewController: ConversationsViewController());
        
        chatNavC.tabBarItem = UITabBarItem(title: MainTabBarVC.tabs[0], image: nil, selectedImage: nil)

        let profileNavC = UINavigationController(rootViewController: ProfileViewController());
        
        profileNavC.tabBarItem = UITabBarItem(title: MainTabBarVC.tabs[2], image: nil, selectedImage: nil)

        let calendarVC = UINavigationController(rootViewController: CalendarViewController());
        
        calendarVC.tabBarItem = UITabBarItem(title: MainTabBarVC.tabs[1], image: nil, selectedImage: nil)

        viewControllers = [chatNavC, calendarVC, profileNavC];
    }
    
    required init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented.")
    }
}
