//
//  ApliInfoViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2017/04/22.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit

class ApliInfoViewController: UIViewController {
    @IBOutlet weak var vertionLabel: UILabel!
    
    //表示制御用タイマー
    private var timer: Timer?
    //String配列のindex用
    private var index: Int = 0
    //表示するString配列
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = APP_INFO
        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        
        vertionLabel.text = "version: " + version
        
    }
    /*******************************************************************
     画面描画時の処理
     *******************************************************************/
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 動画は一旦止める
        if AVPlayerViewControllerManager.shared.controller.player != nil {
            AVPlayerViewControllerManager.shared.controller.player?.pause()
        }
        selectMusicView.isHidden = true
        // navigationbarの色設定
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SETTING.rawValue]
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SETTING.rawValue]]
            self.navigationController!.navigationBar.standardAppearance = appearance
            self.navigationController!.navigationBar.scrollEdgeAppearance = self.navigationController!.navigationBar.standardAppearance
            self.navigationController!.navigationBar.tintColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SETTING.rawValue]
        } else {
            self.navigationController?.navigationBar.barTintColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SETTING.rawValue]
            self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SETTING.rawValue]]
            self.navigationController!.navigationBar.tintColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SETTING.rawValue]
        }
        
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        timer?.invalidate()
    }
    
    func update(timer: Timer) {
        //ここでtextの更新

    }

}
