//
//  HowToUseViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2017/06/10.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import WebKit

class HowToUseViewController: UIViewController ,WKNavigationDelegate, WKUIDelegate {
    
    @IBOutlet weak var waitView: UIVisualEffectView!
    @IBOutlet weak var webView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let webConfiguration = WKWebViewConfiguration()
        
        // ステータスバーの高さを取得する
        let STATUSBARHEIGHT = UIApplication.shared.statusBarFrame.size.height
        // ナビゲーションバーの高さを取得する
        let NAVIGATIONBARHEIGHTNAVIGATIONBARHEIGH = self.navigationController?.navigationBar.frame.size.height
        // タブバーの高さを取得する
        let TABBARHEIGHT = (self.tabBarController?.tabBar.frame.size.height)!
        let wkWebView = WKWebView(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.height - STATUSBARHEIGHT - NAVIGATIONBARHEIGHTNAVIGATIONBARHEIGH! - TABBARHEIGHT), configuration: webConfiguration)

        // スワイプで戻るを許可
        wkWebView.allowsBackForwardNavigationGestures = true
        wkWebView.navigationDelegate = self
        wkWebView.uiDelegate = self
        // 背景色を明示的に設定（ロード前の暗いフラッシュを防ぐ）
        wkWebView.isOpaque = false
        wkWebView.backgroundColor = .systemBackground
        wkWebView.scrollView.backgroundColor = .systemBackground
        webView.backgroundColor = .systemBackground
        if #available(iOS 15.0, *) {
            wkWebView.underPageBackgroundColor = .systemBackground
        }
        if site == HOW_TO_USE {
            self.title = HOW_TO_USE
            if let localURL = Bundle.main.url(forResource: "help", withExtension: "html") {
                wkWebView.loadFileURL(localURL, allowingReadAccessTo: localURL.deletingLastPathComponent())
            } else {
                let accessURL = URL(string: homepageURL)!
                wkWebView.load(URLRequest(url: accessURL))
            }
        } else if site == HOMEPAGE_TITLE {
            self.title = HOMEPAGE_TITLE
            let accessURL = URL(string: homepageURL)
            let myRequest = URLRequest(url: accessURL!)
            wkWebView.load(myRequest)
        } else if site == DRM {
            self.title = DRM
            let accessURL = URL(string: drmURL)
            let myRequest = URLRequest(url: accessURL!)
            wkWebView.load(myRequest)
        }  else {
            self.title = PP_TITLE
            let accessURL = URL(string: ppURL)
            let myRequest = URLRequest(url: accessURL!)
            wkWebView.load(myRequest)
        }
        self.webView.addSubview(wkWebView)
        waitView.isHidden = false
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
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: darkModeLabelColor()]
            self.navigationController!.navigationBar.standardAppearance = appearance
            self.navigationController!.navigationBar.scrollEdgeAppearance = self.navigationController!.navigationBar.standardAppearance
            self.navigationController!.navigationBar.tintColor = AppColor.accent
        } else {
            self.navigationController?.navigationBar.barTintColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SETTING.rawValue]
            self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: darkModeLabelColor()]
            self.navigationController!.navigationBar.tintColor = AppColor.accent
        }
        
//        ingcator.stopAnimating()
//        ingcator.type = INGCATOR_TYPE[NOW_COLOR_THEMA][COLOR_THEMA.SETTING.rawValue]
//        ingcator.color = INGCATOR_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SETTING.rawValue]
//        ingcator.startAnimating()
        
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.request.url?.absoluteString.range(of: "//itunes.apple.com/") != nil {
            if #available(iOS 10.0, *) {
                if UIApplication.shared.responds(to: #selector(UIApplication.open(_:options:completionHandler:))) {
                    UIApplication.shared.open((navigationAction.request.url)!, options: [UIApplication.OpenExternalURLOptionsKey.universalLinksOnly:false], completionHandler: { (finished: Bool) in
                    })
                }
                else {
                    UIApplication.shared.open((navigationAction.request.url)!, options: [:], completionHandler: nil)
                }
            } else {
                // Fallback on earlier versions
            }
        }
        guard let url = navigationAction.request.url else {

            return nil
        }
        
        guard let targetFrame = navigationAction.targetFrame, targetFrame.isMainFrame else {
            webView.load(URLRequest(url: url))
            return nil
        }
        return nil
    }
    /*******************************************************************
     WKWebView Delegate処理
     *******************************************************************/
    // 遷移開始時
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        //waitView.isHidden = true
    }
    // Load完了時
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        waitView.isHidden = true
    }
    
}
