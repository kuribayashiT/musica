//
//  TabAnimationController.swift
//  musica
//
//  Created by 栗林貴大 on 2018/04/29.
//  Copyright © 2018年 K.T. All rights reserved.
//

import UIKit
import RAMAnimatedTabBarController
import TransitionableTab

class TabAnimationController: RAMAnimatedTabBarController{
    // アニメーション設定用
    var type: tabAnimationType = .move
    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self
        if UserDefaults.standard.object(forKey: "scan_trans") == nil {
//            self.tabBar.items![COLOR_THEMA.SCAN.rawValue].badgeValue = "!"
//            UserDefaults.standard.set("true", forKey: "scan_trans")
        }else{
            UserDefaults.standard.bool(forKey: "scan_trans")
        }
        if UserDefaults.standard.object(forKey: "kakinn_tab") == nil {
            self.tabBar.items![COLOR_THEMA.SETTING.rawValue].badgeValue = "!"
            UserDefaults.standard.set("true", forKey: "kakinn_tab")
        }else{
            UserDefaults.standard.bool(forKey: "kakinn_tab")
        }
        if RANKING_PUSH_RECIEVE_FLG {
            self.tabBar.items![COLOR_THEMA.RANKING.rawValue].badgeValue = "!"
        }
        NotificationCenter.default.addObserver(self, selector: #selector(handleSoftwareResetNotification(_:)), name: MySoftwareRestartNotification, object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @objc func handleSoftwareResetNotification(_ notification: Notification) {
        self.presentingViewController?.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

}
extension TabAnimationController: TransitionableTab {
    
    private func fromTransitionAnimation(layer: CALayer, direction: Direction) -> CAAnimation {
        switch type {
        case .move: return DefineAnimation.move(.from, direction: direction)
        case .scale: return DefineAnimation.scale(.from)
        case .fade: return DefineAnimation.fade(.from)
        case .custom:
            let animation = CABasicAnimation(keyPath: "transform.translation.y")
            animation.fromValue = 0
            animation.toValue = -layer.frame.height
            return animation
        }
    }
    
    private func toTransitionAnimation(layer: CALayer, direction: Direction) -> CAAnimation {
        switch type {
        case .move: return DefineAnimation.move(.to, direction: direction)
        case .scale: return DefineAnimation.scale(.to)
        case .fade: return DefineAnimation.fade(.to)
        case .custom:
            let animation = CABasicAnimation(keyPath: "transform.translation.y")
            animation.fromValue = layer.frame.height
            animation.toValue = 0
            return animation
        }
    }
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if TAB_MOVE_FLG == false{
            return false
        }
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
        
        return animateTransition(tabBarController, shouldSelect: viewController)
    }
}
