//
//  iTuneRankingContentsListViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2017/06/25.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import GoogleMobileAds
import SDWebImage
import CoreData
import ReachabilitySwift
import RAMAnimatedTabBarController
import WebKit

class iTuneRankingContentsListViewController: UIViewController{
    @IBOutlet weak var errorView: UIView!
    @IBOutlet weak var waitView: UIView!
    @IBOutlet weak var noneContentsView: UIView!
    
    @IBOutlet weak var youtubeWebView: UIView!
    private var webView: WKWebView!
    // 広告周り
    var adLoader: GADAdLoader!
    let myADView: UIView = UIView()
    var nativeAdView: GADUnifiedNativeAdView!
    var heightConstraint : NSLayoutConstraint?
    var interstitial: GADInterstitial!
    @IBOutlet weak var iTunesImgView: UIImageView!
    @IBOutlet weak var iTunesTitle: UILabel!
    @IBOutlet weak var iTunesArtist: UILabel!
    @IBOutlet weak var iTunesADView: UIView!
    
    var aPVAd: UIView = UIView(frame: CGRect(x:0,y: 0,width: myAppFrameSize.width,height: 100))
    
    var adStartPosition = 0
    var adInterval = 0
    var insertADFlg : Bool = false
    
    // ランキング動画表示周り
    var itunesUrl : String = ""
    var itunesArtwork : String = ""
    var searchMusic : String = ""
    var searchArtist : String = ""
    var searchWord : String = ""
    var searchTitleWord : String = ""
    let reachability = Reachability()!
    @objc dynamic var itemsArray = [AnyObject]()
    @objc dynamic var itemsInfoArray = [AnyObject]()
    var addItemsArray = [AnyObject]()
    var addItemsInfoArray = [AnyObject]()
    
    var nowYoutubeVideoID : String = ""
    var youtubeVideoTitle : String = ""
    var youtubeVideoThumbnailUrl : String = ""
    var youtubeVideoTime : String = ""
    var cellNum : Int = 0
    var nextPageToken : String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let nibObjects = Bundle.main.loadNibNamed("UnifiedNativeAdViewInTableCell", owner: nil, options: nil)
        let adView = (nibObjects?.first as? GADUnifiedNativeAdView)!
        setAdView(adView)
        
        // 自身の変数 test を監視対象として登録
        self.addObserver(self, forKeyPath: "itemsInfoArray", options: [.old, .new], context: nil)
        self.title = searchTitleWord + localText(key:"ranking_neer_mv")
        
        errorView.isHidden = true
        noneContentsView.isHidden = true
        
        // iTunesデータの登録
        iTunesTitle.text = searchMusic
        iTunesArtist.text = searchArtist
        var imgUrl: NSURL = NSURL()
        if let _imgUrl: NSURL = NSURL(string: itunesArtwork as String){
            imgUrl = _imgUrl
        }
        iTunesImgView.sd_setImage(with: imgUrl as URL)
        iTunesADView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.iTunesADTapeed)))
        webView = WKWebView(frame:CGRect(x: 0, y: 0, width: myAppFrameSize.width, height: youtubeWebView.frame.height + getTabHeghtPlusSafeArea()))
        //webView = WKWebView(frame:CGRect(youtubeWebView.frame)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.addObserver(self, forKeyPath: "URL", options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil)
        webView.allowsBackForwardNavigationGestures = true
        youtubeWebView.addSubview(webView)
        self.waitView.isHidden = false
        seachYouTubeVideoInformation(searchWord : searchWord, nextPageToken: "")
    }
    @objc
    func iTunesADTapeed(){
        
        let _itunesUrl = itunesUrl + "&at=1010l344S"
        UIApplication.shared.open(URL(string: _itunesUrl)!, options: [:], completionHandler: nil)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
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
            appearance.backgroundColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.RANKING.rawValue]
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.RANKING.rawValue]]
            self.navigationController!.navigationBar.standardAppearance = appearance
            self.navigationController!.navigationBar.scrollEdgeAppearance = self.navigationController!.navigationBar.standardAppearance
            self.navigationController!.navigationBar.tintColor = NAVIGATION_BTN_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.RANKING.rawValue]
        } else {
            self.navigationController?.navigationBar.barTintColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.RANKING.rawValue]
            self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.RANKING.rawValue]]
            self.navigationController!.navigationBar.tintColor = NAVIGATION_BTN_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.RANKING.rawValue]
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged),name: ReachabilityChangedNotification,object: reachability)
        do{
            try reachability.startNotifier()
        }catch{
            print("could not start reachability notifier")
        }
        
        if ADApearFlg() {
            adStartPosition = SEARCH_RESULT_MV_AD_START
            adInterval = SEARCH_RESULT_MV_AD_INTERVAL
        }else{
            adStartPosition = 0
            adInterval = 0
        }
    }
    // 監視対象の値に変化があった時に呼ばれる
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath {
            case "URL":
                self.waitView.isHidden = false
                print(change![.newKey]!)
                    if let url = String(describing: change![.newKey]!) as? String {
                        if url.hasPrefix("https://www.youtube.com/watch?v=") || url.hasPrefix("https://m.youtube.com/watch?v="){
                            self.nowYoutubeVideoID = url.replacingOccurrences(of: "https://www.youtube.com/watch?v=", with: "")
                            self.nowYoutubeVideoID = url.replacingOccurrences(of: "https://m.youtube.com/watch?v=", with: "")
                            DispatchQueue.main.async {
                                self.webView.goBack()
                                self.performSegue(withIdentifier: "toYoutubePlayer",sender: "")
                                self.waitView.isHidden = true
                            }
                        }else{
                            self.waitView.isHidden = true
                        }
                    }
            case "estimatedProgress":break
            default:
                break
        }
    }
    /*
     Youtube検索結果取得
     */
    func seachYouTubeVideoInformation(searchWord : String , nextPageToken : String) {
        
        if reachability.isReachable {
            let urlString = "https://www.youtube.com/results?search_query=" + searchWord
            let encodedUrlString = urlString.addingPercentEncoding(withAllowedCharacters:NSCharacterSet.urlQueryAllowed)
            let url = NSURL(string: encodedUrlString!)
            let request = NSURLRequest(url: url! as URL)
            webView.load(request as URLRequest)
            self.waitView.isHidden = false
        }else{
            waitView.isHidden = true
            errorView.isHidden = false
            return
        }
    }
    
    // 再読み込みボタン押下時の処理
    @IBAction func reloadBtnTapped(_ sender: Any) {
        seachYouTubeVideoInformation(searchWord : searchWord, nextPageToken: "")
    }
    
    // ネットワーク確認
    @objc func reachabilityChanged(note: Notification) {
        
        let reachability = note.object as! Reachability
        if reachability.isReachable {
            if reachability.isReachableViaWiFi {
                print("Reachable via WiFi")
            } else {
                print("Reachable via Cellular")
            }
        } else {
            print("Network not reachable")
        }
    }
    // 音楽名で検索
    @IBAction func searchMusicNameBtnTapped(_ sender: Any) {
        SEARCH_FARST_WORD = searchMusic
        let animatedTabBar = self.tabBarController as! RAMAnimatedTabBarController
        animatedTabBar.setSelectIndex(from: self.tabBarController!.selectedIndex, to: 2)
    }
    // アーティスト名で検索
    @IBAction func searchArtistNameBtnTapped(_ sender: Any) {
        SEARCH_FARST_WORD = searchArtist
        let animatedTabBar = self.tabBarController as! RAMAnimatedTabBarController
        animatedTabBar.setSelectIndex(from: self.tabBarController!.selectedIndex, to: 2)
    }
    /*******************************************************************
     画面遷移時処理
     *******************************************************************/
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toYoutubePlayer" {
            let secondVc = segue.destination as! YoutubeVideoViewController
            // 値を渡す
            secondVc.nowYoutubeVideoID = nowYoutubeVideoID
            secondVc.youtubeVideoTitle = youtubeVideoTitle
            secondVc.youtubeVideoThumbnailUrl = youtubeVideoThumbnailUrl
            secondVc.youtubeVideoTime = youtubeVideoTime
            secondVc.fromView = COLOR_THEMA.RANKING
        }
    }
    // オブジェクト破棄時に監視を解除
    deinit {
        self.waitView.isHidden = true
        self.removeObserver(self, forKeyPath: "itemsInfoArray")
        self.webView?.removeObserver(self, forKeyPath: "estimatedProgress")
        self.webView?.removeObserver(self, forKeyPath: "URL")
        //イベントリスナーの削除
        NotificationCenter.default.removeObserver(self)
    }
}

extension iTuneRankingContentsListViewController: WKUIDelegate, WKNavigationDelegate {

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Swift.Void) {
        if let url = navigationAction.request.url?.absoluteString {
            if url.hasPrefix("https://www.youtube.com/watch?v=") || url.hasPrefix("https://m.youtube.com/watch?v="){
                decisionHandler(.cancel)
            }
        }
        decisionHandler(.allow)
    }
    // WKWebViewで読み込みが開始された際に実行する処理
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        waitView.isHidden = false
    }
    // WKWebViewで読み込みが完了した際に実行する処理
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        waitView.isHidden = true
    }
    // WKWebViewで読み込みが失敗した際に実行する処理
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        waitView.isHidden = true
        errorView.isHidden = true
    }
    // WKWebView内における3Dタッチを設定に関する設定(trueにすると有効になる)
    func webView(_ webView: WKWebView, shouldPreviewElement elementInfo: WKPreviewElementInfo) -> Bool {
        return false
    }
    // MARK: - リダイレクト
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation:WKNavigation!) {
    }
}
