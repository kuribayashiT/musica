//
//  PopUpAdDialog.swift
//  musica
//
//  Created by 栗林貴大 on 2020/09/13.
//  Copyright © 2020 K.T. All rights reserved.
//

import UIKit
import GoogleMobileAds

class PopUpAdDialog: UIView {

    @IBOutlet weak var baseView: UIView!
    @IBOutlet weak var baseAdView: UIView!
    @IBOutlet weak var removeAdBtn: UIButton!
    @IBOutlet weak var clloseBtn: UIButton!
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    @IBAction func removeAdBtnTapped(_ sender: Any) {
        let mainStoryboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let secondViewController = mainStoryboard.instantiateViewController(withIdentifier: "removeADPayVC") as! RemoveADViewController
        self.removeFromSuperview()
        let vc = getForegroundViewController()
        if let tabController = vc as? UITabBarController {
            if let selected = tabController.selectedViewController {
                if let navigationController = selected as? UINavigationController {
                    navigationController.pushViewController(secondViewController, animated: true)
                    return
                }
            }
        }
        if let navigationController = vc as? UINavigationController {
            navigationController.pushViewController(secondViewController, animated: true)
            return
        }
        vc.present(secondViewController, animated: true)
    }
    @IBAction func closeBtnTapped(_ sender: Any) {
        if adDialogLoader != nil {
            adDialogLoader.load(GADRequest())
        }
        self.removeFromSuperview()
    }
    
}
