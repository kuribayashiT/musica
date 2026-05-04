//
//  TabAnimationController.swift
//  musica
//
//  Created by 栗林貴大 on 2018/04/29.
//  Copyright © 2018年 K.T. All rights reserved.
//
 
import UIKit
                                                          
class TabAnimationController: UITabBarController {

    private var tabConfigs: [(symbol: String, title: String)] {
        [
            ("house.fill",           localText(key: "tab_home")),
            ("headphones",           localText(key: "tab_practice")),
            ("play.rectangle.fill",  localText(key: "tab_discovery")),
            ("doc.text.fill",        localText(key: "tab_text")),
            ("gearshape.fill",       localText(key: "tab_options")),
        ]
    }
 
    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self
        setupTabBarItems()
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleSoftwareResetNotification(_:)),
            name: MySoftwareRestartNotification, object: nil)
    }
                                                                                                                                                                               
    // injectPracticeTab() の setViewControllers 後に自動で再適用
    override func setViewControllers(_ viewControllers: [UIViewController]?, animated: Bool) {
        super.setViewControllers(viewControllers, animated: animated)
        setupTabBarItems()
    }
                                                          
    private func setupTabBarItems() {
        for (i, item) in (tabBar.items ?? []).enumerated() {
            guard i < tabConfigs.count else { break }
            item.image         = UIImage(systemName: tabConfigs[i].symbol)
            item.selectedImage = UIImage(systemName: tabConfigs[i].symbol)
            item.title         = tabConfigs[i].title
        }
        
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = .systemGray
        itemAppearance.normal.titleTextAttributes   = [.foregroundColor: UIColor.systemGray]
        itemAppearance.selected.iconColor = AppColor.accent
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: AppColor.accent]

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        tabAppearance.stackedLayoutAppearance = itemAppearance

        tabBar.standardAppearance  = tabAppearance
        tabBar.scrollEdgeAppearance = tabAppearance
        tabBar.tintColor = AppColor.accent
                                                          
        if UserDefaults.standard.object(forKey: "kakinn_tab") == nil {
            self.tabBar.items![COLOR_THEMA.SETTING.rawValue].badgeValue = "!"
            UserDefaults.standard.set("true", forKey: "kakinn_tab")
        }
        if RANKING_PUSH_RECIEVE_FLG {
            self.tabBar.items![COLOR_THEMA.RANKING.rawValue].badgeValue = "!"
        }
    }
                                                                                                                                                                               
    @objc func handleSoftwareResetNotification(_ notification: Notification) {
        presentingViewController?.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension TabAnimationController: UITabBarControllerDelegate {

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        guard TAB_MOVE_FLG else { return false }
                                                                                                                                                                               
        if viewController.tabBarItem == self.tabBar.items![COLOR_THEMA.SCAN.rawValue] {
            self.tabBar.items![COLOR_THEMA.SCAN.rawValue].badgeValue = nil
            UserDefaults.standard.bool(forKey: "scan_trans")
        }
        if viewController.tabBarItem == self.tabBar.items![COLOR_THEMA.SETTING.rawValue] {
            self.tabBar.items![COLOR_THEMA.SETTING.rawValue].badgeValue = nil
            UserDefaults.standard.bool(forKey: "kakinn_tab")
        }
        if viewController.tabBarItem == self.tabBar.items![COLOR_THEMA.RANKING.rawValue] {
            self.tabBar.items![COLOR_THEMA.RANKING.rawValue].badgeValue = nil
            RANKING_PUSH_RECIEVE_FLG = false
        }
        return true
    }
}
