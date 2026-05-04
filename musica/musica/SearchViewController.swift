//
//  SearchViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2017/05/31.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import GoogleMobileAds
import SDWebImage
import AVFoundation
import Reachability
import CoreData
import DGElasticPullToRefresh
import Firebase
import XCDYouTubeKit
import WebKit

class SearchViewController: UIViewController , UISearchBarDelegate  ,APVAdManagerDelegate, NAAdViewDelegate{

    @IBOutlet weak var recommendMVViewHeight: NSLayoutConstraint!
    @IBOutlet weak var youtubeWebView: UIView!
    @IBOutlet weak var youtubeViewBotmM: NSLayoutConstraint!
    /*
     ボタン関連
     */

    @IBOutlet weak var reloadBtn: UIButton!
    @IBOutlet weak var categoryIDBtn: UIButton!
    @IBOutlet weak var resetBtn: UIButton!
    /*
     おすすめ関連
     */
    @IBOutlet weak var recommendSearchWdView: UIView!
    @IBOutlet weak var recommendMVView: UIView!
    @IBOutlet weak var recommendWardTitle: UILabel!
    @IBOutlet weak var recommendWardCollectView: UICollectionView!
    @IBOutlet weak var recommendMVCollectView: UICollectionView!
    @IBOutlet weak var recommendMVBtn: UIButton!
    
    /*
     広告周り
     */
    let popupView:PopUpAdDialog = UINib(nibName: "PopUpDialog", bundle: nil).instantiate(withOwner: self,options: nil)[0] as! PopUpAdDialog
    var adCollectLoader: AdLoader!
    //var adDialogLoader: AdLoader!
    var nativeAdView: NativeAdView!
    var nativeAdRecommendView: NativeAdView!
    var nativeAdDialogView: NativeAdView!
    let myADView: UIView = UIView()
    let myADViewRecomend: UIView = UIView()
    let myADViewDialog: UIView = UIView()
    var heightConstraint : NSLayoutConstraint?
    var size = CGSize()
    @IBOutlet weak var bannerView: BannerView!
    var adStartPosition = 0
    var adInterval = 0
    var insertADFlg : Bool = false
    var aPVAd: UIView = UIView(frame: CGRect(x:0,y: 100,width: myAppFrameSize.width,height: myAppFrameSize.width * 9 / 16))
    var aPVAdManager: APVAdManager?
    @IBOutlet weak var ADView: UIView!
    private var webView: WKWebView!
    /*
     検索結果table関連
     */
    @IBOutlet weak var searchResultTableView: UITableView!
    @IBOutlet weak var seachTextField: UISearchBar!
    var nonDataFlg = false
    @objc dynamic var viewReloadFlg = false
    @objc dynamic var itemsArray = [AnyObject]()
    @objc dynamic var itemsInfoArray = [AnyObject]()
    var addItemsArray = [AnyObject]()
    var addItemsInfoArray = [AnyObject]()
    
    var nextPageToken : String = ""
    var searchWord : String = ""
    @IBOutlet weak var noHitSearchWordLabel: UILabel!
    var nowYoutubeVideoID : String = ""
    var youtubeVideoTitle : String = ""
    var youtubeVideoThumbnailUrl : String = ""
    var youtubeVideoTime : String = ""
    var cellNum : Int = 0
    var searchTutorialFlg = false
    /*
     切り替えView
     */
    @IBOutlet weak var waitView: UIVisualEffectView!
    @IBOutlet weak var errorView: UIView!
    @IBOutlet weak var noHitView: UIView!
    
    @IBOutlet weak var errTextView: UITextView!
    /*
     オフライン検知
     */
    let reachability = try! Reachability()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        recommendMVView.translatesAutoresizingMaskIntoConstraints = false
        recommendWardTitle.text = localText(key:"search_recommend_wards")
        /*
         端末によるサイズの計算とviewの設定
         */
        // 初期化
        nextPageToken = ""
        searchWord = ""
        searchResultTableView.rowHeight = UITableView.automaticDimension
        searchResultTableView.estimatedRowHeight = CELL_ROW_HEIGT_THICK
        
        recommendMVBtn.setTitle(localText(key:"search_recommend_mv_message"),for: .normal)
        // 各Viewの表示設定
        errorView.isHidden = true
        waitView.isHidden = true
        noHitView.isHidden = true
        size = CGSize(width: searchResultTableView.frame.size.width, height: searchResultTableView.frame.size.height)
        ADView.isHidden = true
        resetBtn.setTitle(localText(key: "trans_btn_clear"), for: .normal)
        /*
         tableviewカスタマイズ
         */
        if #available(iOS 11.0, *) {
            let loadingView = DGElasticPullToRefreshLoadingViewCircle()
            loadingView.tintColor = AppColor.navigationForeground
                searchResultTableView.dg_addPullToRefreshWithActionHandler({ [weak self] () -> Void in
                    getRecommendMV(collect:self!.recommendMVCollectView)
                    getRecommendWard(collect:self!.recommendWardCollectView)
                    self?.searchResultTableView.reloadData()
                    if AD_DISPLAY_SEARCH_BANNER {custumLoadBannerAd(bannerView: self!.bannerView,setBannerView:self!.view)}
                    self?.searchResultTableView.dg_stopLoading()
                }, loadingView: loadingView)
        }
        popupView.frame = CGRect(x: 0, y: 0, width: myAppFrameSize.width, height: myAppFrameSize.height)
        popupView.removeAdBtn.setTitle(REMOVE_AD, for: .normal)
        popupView.clloseBtn.setTitle(MESSAGE_CLOSE, for: .normal)
        // 検索周りの設定
        seachTextField.delegate = self
        seachTextField.searchBarStyle = UISearchBar.Style.default
        seachTextField.showsSearchResultsButton = false
        seachTextField.placeholder = localText(key:"search")
        seachTextField.showsCancelButton = true
        seachTextField.tintColor = AppColor.accent
        reloadBtn.setTitleColor(AppColor.inactive, for: .highlighted)
        categoryIDBtn.tintColor = AppColor.accent
        searchResultTableView.isEditing = false
        // キーボードの「閉じる」ボタン作成
        let kbToolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 40))
        kbToolBar.barStyle = UIBarStyle.default  // スタイルを設定
        kbToolBar.sizeToFit()  // 画面幅に合わせてサイズを変更
        // スペーサー
        let spacer = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: self, action: nil)
        // 閉じるボタン
        let commitButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.done, target: self, action: #selector(self.editCloseBtnTapped))
        kbToolBar.items = [spacer, commitButton]
        seachTextField.inputAccessoryView = kbToolBar

        recommendMvHiddenFlg = false
        // recommend周りの設定
        recommendWardCollectView.delegate = self
        recommendWardCollectView.dataSource = self
        recommendMVCollectView.delegate = self
        recommendMVCollectView.dataSource = self
        recommendMVCollectView.register(UINib(nibName: "RecommendMVCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "mv")
        // WKWebViewを生成
        webView = WKWebView(frame:CGRect(x: 0, y: 0, width: myAppFrameSize.width, height: youtubeWebView.frame.height +
                                         UIApplication.shared.statusBarFrame.height + getTabHeghtPlusSafeArea()))
        recommendMVView.isHidden = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.addObserver(self, forKeyPath: "URL", options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil)
        webView.allowsBackForwardNavigationGestures = true
        youtubeWebView.addSubview(webView)
        youtubeWebView.isHidden = true
        
        myADViewDialog.frame =  CGRect(x: 0, y: 0 , width: myAppFrameSize.width - 32 ,height:(myAppFrameSize.width - 32) * 15/32 + 70)
        popupView.baseAdView.addSubview(myADViewDialog)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      // AdMobバナー広告の読み込み
      if AD_DISPLAY_SEARCH_BANNER{
          bannerView.adUnitID = ADMOB_BANNER_ADUNIT_ID
          bannerView.rootViewController = self
          bannerView.isHidden = false
          custumLoadBannerAd(bannerView: bannerView!,setBannerView:self.view)
          //bannerView.load(requestBanner)
      }else{
          BANNERHEIGHT = 0
          bannerView.isHidden = true
      }
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
        self.navigationController?.navigationBar.isTranslucent = false
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SEARCH.rawValue]
            appearance.titleTextAttributes =  [NSAttributedString.Key.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SEARCH.rawValue]]
            self.navigationController!.navigationBar.standardAppearance = appearance
            self.navigationController!.navigationBar.scrollEdgeAppearance = self.navigationController!.navigationBar.standardAppearance
            self.navigationController!.navigationBar.tintColor = AppColor.accent
        } else {
            self.navigationController?.navigationBar.barTintColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SEARCH.rawValue]
            self.navigationController?.navigationBar.titleTextAttributes =  [NSAttributedString.Key.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SEARCH.rawValue]]
            self.navigationController!.navigationBar.tintColor = AppColor.accent
        }
        
        searchResultTableView.dg_setPullToRefreshFillColor(NAVIGATION_PTR_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SEARCH.rawValue])
        searchResultTableView.dg_setPullToRefreshBackgroundColor(searchResultTableView.backgroundColor!)
        categoryIDBtn.tintColor = AppColor.textSecondary
        
        let nibObjectsCollect = Bundle.main.loadNibNamed("UnifiedNativeAdViewAboutRecommend", owner: nil, options: nil)
        let adViewCollect = (nibObjectsCollect?.first as? NativeAdView)!
        let nibObjectsDialog = Bundle.main.loadNibNamed("PopUpAdView", owner: nil, options: nil)
        let adViewDialog = (nibObjectsDialog?.first as? NativeAdView)!
        setAdView(adViewCollect,adUnitID: ADMOB_NATIVE_ADVANCE_SEARCH_RECOMMEND)
        setAdView(adViewDialog,adUnitID: ADMOB_NATIVE_ADVANCE_DIALOG_RECOMMEND)
        
        // 広告の準備
        if ADApearFlg() && AD_DISPLAY_SEARCH_BANNER{
            recommendMVViewHeight.constant = CGFloat(264)
        }else{
            recommendMVViewHeight.constant = CGFloat(214)
            BANNERHEIGHT = 0
        }
        recommendSearchWdView.isHidden = judgeDisplayRecommendWard(flg:true)
        if NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLACK.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_BLUE.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_RED.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLUE.rawValue {
            categoryIDBtn.layer.borderWidth = 1
            categoryIDBtn.layer.borderColor = AppColor.textSecondary.cgColor
        }else{
            categoryIDBtn.layer.borderWidth = 0
            categoryIDBtn.layer.borderColor = UIColor.clear.cgColor
        }
        
        if SEARCH_FARST_WORD != "" {
            seachTextField.text = SEARCH_FARST_WORD
            SEARCH_FARST_WORD = ""
            self.itemsInfoArray = [AnyObject]()
            self.itemsArray = [AnyObject]()
            self.nextPageToken = ""
            self.searchResultTableView.reloadData()
            seachTextField.becomeFirstResponder()
        }
        do {
            try reachability.startNotifier()
            //if reachability.isReachable {searchResultTableView.reloadData()}
        } catch  {
            // エラー処理
            dlog("could not start reachability notifier")
        }
        // キーボードの設定
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.keyboardWillBeShown(notification:)),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.keyboardWillHide(notification:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.keyboardDidHide(notification:)),
            name: UIResponder.keyboardDidHideNotification,
            object: nil
        )
        // 広告数
        if ADApearFlg() {
            adStartPosition = SEARCH_RESULT_MV_AD_START
            adInterval = SEARCH_RESULT_MV_AD_INTERVAL
        }else{
            adStartPosition = 0
            adInterval = 0
        }
        NotificationCenter.default.addObserver(self, selector: #selector(self.reachabilityChanged),name: ReachabilityChangedNotification,object: reachability)
        self.recommendMVCollectView.reloadData()
        //self.searchResultTableView.reloadData()
    }
    
    // 監視対象の値に変化があった時に呼ばれる
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath {
            case "itemsInfoArray":
                // Viewの更新はメインスレッドで実行
                DispatchQueue.main.async {
                    if self.nonDataFlg {
                        // 各Viewの表示設定
                        self.errorView.isHidden = true
                        self.waitView.isHidden = true
                        self.noHitView.isHidden = false
                        self.nonDataFlg = false
                    }
                    self.searchResultTableView.reloadData()
                }
        case "URL":
            recommendWardHiddenFlg = true
            self.waitView.isHidden = false
            dlog(change![.newKey]!)
                if let url = String(describing: change![.newKey]!) as? String {
                    if url.hasPrefix("https://www.youtube.com/watch?v=") || url.hasPrefix("https://m.youtube.com/watch?v=") {
                        self.nowYoutubeVideoID = url.replacingOccurrences(of: "https://www.youtube.com/watch?v=", with: "")
                        self.nowYoutubeVideoID = self.nowYoutubeVideoID.replacingOccurrences(of: "https://m.youtube.com/watch?v=", with: "")
                        DispatchQueue.main.async {
                            self.webView.goBack()
                            self.performSegue(withIdentifier: "toYoutubePlayer", sender: "")
                            self.waitView.isHidden = true
                        }
                    } else if url.contains("/shorts/") {
                        // YouTube Shorts URL: https://www.youtube.com/shorts/VIDEO_ID
                        let parts = url.components(separatedBy: "/shorts/")
                        if let rawID = parts.last, !rawID.isEmpty {
                            let videoID = rawID.components(separatedBy: "?").first ?? rawID
                            self.nowYoutubeVideoID = videoID
                            self.youtubeVideoTitle = ""
                            DispatchQueue.main.async {
                                self.webView.goBack()
                                self.performSegue(withIdentifier: "toYoutubePlayer", sender: "")
                                self.waitView.isHidden = true
                            }
                        } else {
                            self.waitView.isHidden = true
                        }
                    } else {
                        self.waitView.isHidden = true
                    }
                }
            case "estimatedProgress":break
            
            default:
                break
        }
    }
    
    /*******************************************************************
     検索結果取得処理
     *******************************************************************/
    func seachYouTubeVideoInformation(searchWord : String , nextPageToken : String) {
        if SEARCH_MV_AD_INTERVAL != 0 && SEARCH_TO_MV % SEARCH_MV_AD_INTERVAL == 0{
            if ADApearFlg() {
                if adDialogLoader.isLoading == false {
                    UIApplication.shared.keyWindow?.rootViewController!.view.addSubview(popupView)
                    dialogPopUpAnimesion(view: popupView.baseView)
                }
            }
        }
        // ネットワーク接続を確認
        var searchWordEncoded = ""
        if reachability.isReachable {
            dlog("online")
            self.view.endEditing(true)
            searchWordEncoded = searchWord.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ??  "エンコードできませんでした"
            // 各Viewの表示設定
            errorView.isHidden = true
            waitView.isHidden = false
            ADView.isHidden = true
            noHitView.isHidden = true
        }else{
            dlog("offlone")
            // 各Viewの表示設定
            errorView.isHidden = false
            waitView.isHidden = true
            ADView.isHidden = true
            noHitView.isHidden = true
            return
        }
        // FA送信
        if !DEBUG_FLG {
            Analytics.logEvent("検索", parameters: [
                "検索ワード": searchWord as NSObject
                ])
        }
        setSearchWordData(searchWord:searchWord)
        let urlString = "https://www.youtube.com/results?search_query=" + searchWord
        let encodedUrlString = urlString.addingPercentEncoding(withAllowedCharacters:NSCharacterSet.urlQueryAllowed)

        let url = NSURL(string: encodedUrlString!)
        let request = NSURLRequest(url: url! as URL)

        webView.load(request as URLRequest)
        recommendSearchWdView.isHidden = judgeDisplayRecommendWard(flg:true)
        recommendMVView.isHidden = true
        youtubeWebView.isHidden = false
    }
    

    /*******************************************************************
     text編集周りの処理
     *******************************************************************/
    //キーボードが開くときの呼び出しメソッド
    @objc func keyboardWillBeShown(notification:NSNotification) {
        // キーボード閉じるボタンを表示
        recommendSearchWdView.isHidden = judgeDisplayRecommendWard(flg:false)
    }
    // キーボード閉じる時
    @objc func keyboardWillHide(notification: NSNotification) {
        recommendSearchWdView.isHidden = judgeDisplayRecommendWard(flg:true)
    }
    // キーボード閉じた後
    @objc func keyboardDidHide(notification: NSNotification) {
        // 広告を非表示
        //ADView.isHidden = true
    }
    // テキストフィールド入力開始前に呼ばれる
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        searchBar.showsCancelButton = true
        return true
    }
    @objc func editCloseBtnTapped() {
        //キーボードを閉じる
        seachTextField.resignFirstResponder()
    }
    /*******************************************************************
     ボタンタップ時処理
     *******************************************************************/
    @IBAction func resetBtnTapped(_ sender: Any) {
        seachTextField.showsCancelButton = false
        self.view.endEditing(true)
        seachTextField.text = ""
        // 各Viewの表示設定
        errorView.isHidden = true
        waitView.isHidden = true
        noHitView.isHidden = true
        recommendMvHiddenFlg = false
        recommendMVView.isHidden = judgeDisplayRecommendMV(flg:false)
        searchResultTableView.isHidden = false
        if itemsInfoArray.count != 0 {
            ADView.isHidden = true
            self.itemsInfoArray = [AnyObject]()
            self.itemsArray = [AnyObject]()
            self.nextPageToken = ""
            self.searchResultTableView.reloadData()
        }
    }
    
    @IBAction func recommendMVBtnTapped(_ sender: Any) {
        showToastMsg(messege:localText(key:"search_recommend_mv_tapped_message"),time:2.0, tab: COLOR_THEMA.SEARCH.rawValue)
    }
    @IBAction func reloadBtnTapped(_ sender: Any) {
        if reachability.isReachable {
            self.view.endEditing(true)
            searchWord = seachTextField.text!
            seachYouTubeVideoInformation(searchWord: searchWord, nextPageToken: "")
            insertADFlg = false
            // 各Viewの表示設定
            errorView.isHidden = true
            waitView.isHidden = false
            ADView.isHidden = true
            noHitView.isHidden = true
            
        }else{
            dlog("offlone")
            // 各Viewの表示設定
            errorView.isHidden = false
            waitView.isHidden = true
            ADView.isHidden = true
            noHitView.isHidden = true
        }
    }
    
    // キャンセルボタンが押された時に呼ばれる
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.showsCancelButton = false
        self.view.endEditing(true)
        searchBar.text = ""
        // 各Viewの表示設定
        errorView.isHidden = true
        waitView.isHidden = true
        noHitView.isHidden = true
        recommendMVView.isHidden = judgeDisplayRecommendMV(flg:false)
        if itemsInfoArray.count != 0 {
            ADView.isHidden = true
            self.itemsInfoArray = [AnyObject]()
            self.itemsArray = [AnyObject]()
            self.nextPageToken = ""
            self.searchResultTableView.reloadData()
        }else{
            if AD_DISPLAY_SEARCH_CONTENTS {
                ADView.isHidden = false
            }else{
                ADView.isHidden = true
            }
        }
    }
    
    // 検索ボタンが押された時に呼ばれる
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.view.endEditing(true)
        // 各Viewの表示設定
        errorView.isHidden = true
        waitView.isHidden = false
        noHitView.isHidden = true
        recommendMVView.isHidden = judgeDisplayRecommendMV(flg : true)
        noHitSearchWordLabel.text = "「" + self.seachTextField.text! + "」"
        seachYouTubeVideoInformation(searchWord:  seachTextField.text!, nextPageToken: "")
    }
    // カテゴリ設定ボタンが押された時の処理
    @IBAction func categoryBtnTapped(_ sender: Any) {
        let actionSheet = UIAlertController(title: localText(key:"search_janre_setting_title"), message: localText(key:"search_janre_setting_body"), preferredStyle:UIAlertController.Style.actionSheet)
        
        let action1 = setCategoryActionsheet(categoryID : SETTING_CATEGORYID[0])
        let action2 = setCategoryActionsheet(categoryID : SETTING_CATEGORYID[1])
        let action3 = setCategoryActionsheet(categoryID : SETTING_CATEGORYID[2])
        let action4 = setCategoryActionsheet(categoryID : SETTING_CATEGORYID[3])
        let action5 = setCategoryActionsheet(categoryID : SETTING_CATEGORYID[4])
        let action6 = setCategoryActionsheet(categoryID : SETTING_CATEGORYID[5])
        let action7 = setCategoryActionsheet(categoryID : SETTING_CATEGORYID[6])
        let action8 = setCategoryActionsheet(categoryID : SETTING_CATEGORYID[7])
        let action9 = setCategoryActionsheet(categoryID : SETTING_CATEGORYID[8])
        let action10 = setCategoryActionsheet(categoryID : SETTING_CATEGORYID[9])
        let action11 = setCategoryActionsheet(categoryID : SETTING_CATEGORYID[10])
        let action12 = setCategoryActionsheet(categoryID : SETTING_CATEGORYID[11])
        
        let cancel = UIAlertAction(title: localText(key:"btn_cancel"), style: UIAlertAction.Style.cancel, handler: {
            (action: UIAlertAction!) in
            dlog("キャンセルをタップした時の処理")
        })
        
        actionSheet.addAction(action1)
        actionSheet.addAction(action2)
        actionSheet.addAction(action3)
        actionSheet.addAction(action4)
        actionSheet.addAction(action5)
        actionSheet.addAction(action6)
        actionSheet.addAction(action7)
        actionSheet.addAction(action8)
        actionSheet.addAction(action9)
        actionSheet.addAction(action10)
        actionSheet.addAction(action11)
        actionSheet.addAction(action12)
        actionSheet.addAction(cancel)
        
        self.present(actionSheet, animated: true, completion: nil)
    }
    // カテゴリ設定のActionSheetのラッパー
    func setCategoryActionsheet(categoryID: Int ) -> UIAlertAction{
        var style = UIAlertAction.Style.default
        switch categoryID {
        case SETTING_CATEGORYID[0]:
            if SETTING_NOW_CATEGORYID == categoryID{
                style = UIAlertAction.Style.destructive
            }
        case SETTING_CATEGORYID[1]:
            if SETTING_NOW_CATEGORYID == categoryID{
                style = UIAlertAction.Style.destructive
            }
        case SETTING_CATEGORYID[2]:
            if SETTING_NOW_CATEGORYID == categoryID{
                style = UIAlertAction.Style.destructive
            }
        case SETTING_CATEGORYID[3]:
            if SETTING_NOW_CATEGORYID == categoryID{
                style = UIAlertAction.Style.destructive
            }
        case SETTING_CATEGORYID[4]:
            if SETTING_NOW_CATEGORYID == categoryID{
                style = UIAlertAction.Style.destructive
            }
        case SETTING_CATEGORYID[5]:
            if SETTING_NOW_CATEGORYID == categoryID{
                style = UIAlertAction.Style.destructive
            }
        case SETTING_CATEGORYID[6]:
            if SETTING_NOW_CATEGORYID == categoryID{
                style = UIAlertAction.Style.destructive
            }
        case SETTING_CATEGORYID[7]:
            if SETTING_NOW_CATEGORYID == categoryID{
                style = UIAlertAction.Style.destructive
            }
        case SETTING_CATEGORYID[8]:
            if SETTING_NOW_CATEGORYID == categoryID{
                style = UIAlertAction.Style.destructive
            }
        case SETTING_CATEGORYID[9]:
            if SETTING_NOW_CATEGORYID == categoryID{
                style = UIAlertAction.Style.destructive
            }
        case SETTING_CATEGORYID[10]:
            if SETTING_NOW_CATEGORYID == categoryID{
                style = UIAlertAction.Style.destructive
            }
        case SETTING_CATEGORYID[11]:
            if SETTING_NOW_CATEGORYID == categoryID{
                style = UIAlertAction.Style.destructive
            }
        default: break
        }
        
        let action = UIAlertAction(title: String(SETTING_CATEGORY_NAME[SETTING_CATEGORYID.index(of: categoryID)!]), style: style, handler: {
            (action: UIAlertAction!) in
            SETTING_NOW_CATEGORYID = categoryID
            self.categoryIDBtn.setTitle(SETTING_CATEGORY_NAME[SETTING_CATEGORYID.index(of: categoryID)!], for: .normal)
            self.itemsInfoArray = [AnyObject]()
            self.itemsArray = [AnyObject]()
            self.nextPageToken = ""
            if self.seachTextField.text! != "" {
                self.seachYouTubeVideoInformation(searchWord: self.seachTextField.text!, nextPageToken: "")
            }
        })
        
        return action
    }
    // 「もっと見る」ボタンタップ時
    @objc func moreDataload(_ sender: AnyObject) {
        seachYouTubeVideoInformation(searchWord: seachTextField.text!, nextPageToken: nextPageToken)
        if ADApearFlg() {
            if adDialogLoader.isLoading == false {
                UIApplication.shared.keyWindow?.rootViewController!.view.addSubview(popupView)
                dialogPopUpAnimesion(view: popupView.baseView)
            }
        }
    }
    
    @IBAction func recommendMVTitleLabelTapped(_ sender: Any) {
        showToastMsg(messege:LISTMODE_LIVRARY_DELETE_TRACK,time:2.0, tab: COLOR_THEMA.SEARCH.rawValue)
    }
    /*******************************************************************
     広告関連の処理
     *******************************************************************/
    // Adds native express ads to the tableViewItems list.
    func addAdsTocontents(ArrayName : String) {
        if adStartPosition <= 0 {
            return
        }
        var index = adStartPosition
        DispatchQueue.main.async {
            self.searchResultTableView.layoutIfNeeded()
        }
        if ArrayName == "addItemsArray" {
            while index < addItemsArray.count {
                let nibObjects = Bundle.main.loadNibNamed("UnifiedNativeAdViewInTableCell", owner: nil, options: nil)
                let adView = (nibObjects?.first as? NativeAdView)!
                let adFlg = adView
                addItemsArray.insert(adFlg as AnyObject, at: index)
                index += adInterval
            }
        } else if ArrayName == "addItemsInfoArray" {
            while index < addItemsInfoArray.count {
                let nibObjects = Bundle.main.loadNibNamed("UnifiedNativeAdViewInTableCell", owner: nil, options: nil)
                let adView = (nibObjects?.first as? NativeAdView)!
                let adFlg = adView
                addItemsInfoArray.insert(adFlg as AnyObject, at: index)
                index += adInterval
            }
        }
    }
    /*******************************************************************
     ネットワーク確認処理
     *******************************************************************/
    // ネットワーク確認
    @objc func reachabilityChanged(note: Notification) {
        
        let reachability = note.object as! Reachability
        
        if reachability.isReachable {
            if reachability.isReachableViaWiFi {
                dlog("Reachable via WiFi")
            } else {
                dlog("Reachable via Cellular")
            }
        } else {
            dlog("Network not reachable")
        }
    }
    func checkOffline(){
        if reachability.isReachable {
            dlog("online")
        }else{
            dlog("offlone")
            waitView.isHidden = true
            errorView.isHidden = false
            return
        }
    }
    /*******************************************************************
     広告関連の処理
     *******************************************************************/
    func adViewDidFail(toLoad view: AmazonAdView!, withError: AmazonAdError!) -> Void {}
    func adViewWillExpand(_ view: AmazonAdView!) -> Void {}
    func adViewDidCollapse(_ view: AmazonAdView!) -> Void {}
    // AmazonAdViewDelegate APVAdManagerDelegate で使う
    func viewControllerForPresentingModalView() -> UIViewController! {
        return self
    }
    func onReady(toPlayAd ad: APVAdManager!, for nativeAd: APVNativeAd!) {
        ad.showAd(for: aPVAd)
    }
    
    /*******************************************************************
     画面遷移時処理
     *******************************************************************/
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //Track 一覧画面へ
        if segue.identifier == "toYoutubePlayer" {
            let secondVc = segue.destination as! YoutubeVideoViewController
            // 値を渡す
            secondVc.nowYoutubeVideoID = self.nowYoutubeVideoID
            secondVc.youtubeVideoTitle = self.youtubeVideoTitle
            secondVc.youtubeVideoThumbnailUrl = self.youtubeVideoThumbnailUrl
            secondVc.youtubeVideoTime = self.youtubeVideoTime
            secondVc.fromView = COLOR_THEMA.SEARCH
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        //イベントリスナーの削除
        NotificationCenter.default.removeObserver(self)
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
/*******************************************************************

*******************************************************************/
extension SearchViewController :  UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView.tag == 0 {
            if recomendWardList.count == 0 {
                recommendWardHiddenFlg = true
            }else{
                recommendWardHiddenFlg = false
            }
            return recomendWardList.count
        }else{
            if recomendMvList.count == 0 {
                recommendMvHiddenFlg = true
                recommendMVView.isHidden = judgeDisplayRecommendMV(flg : true)
                return recomendMvList.count
            }else{
                if itemsInfoArray.count == 0{
                    recommendMVView.isHidden = judgeDisplayRecommendMV(flg : false)
                }else{
                    recommendMVView.isHidden = judgeDisplayRecommendMV(flg : true)
                }
                if ADApearFlg() && SEARCH_RECOMMEND_AD {
                    return recomendMvList.count + 1
                }
                return recomendMvList.count
            }
        }
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView.tag == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ward", for: indexPath) as! RecommendWardCollectionViewCell
            cell.ward.text = recomendWardList[indexPath.row]
            return cell
        }else{
            var index = indexPath.row
            if ADApearFlg() && SEARCH_RECOMMEND_AD {
                index = indexPath.row - 1
            }
            if index == -1 {
                // 初期化
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "mvAD", for: indexPath)
                cell.layer.shadowOffset = CGSize(width: 0.0, height: 2.0)
                cell.layer.shadowColor = AppColor.shadow.cgColor
                cell.layer.shadowOpacity = 0.6
                cell.layer.shadowRadius = 3
                myADViewRecomend.layer.cornerRadius = 12
                let bgView = UIView()
                //bgView.backgroundColor = AppColor.inactive
                //cell.frame = CGRect(x: 0, y: 0 , width: 150 ,height:174)
                bgView.frame = CGRect(x: 4, y: 16 , width: 142 ,height:142)
                bgView.layer.cornerRadius = 12
                cell.addSubview(bgView)
                cell.addSubview(myADViewRecomend)
                return cell
            }else{
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "mv", for: indexPath) as! RecommendMVCollectionViewCell
                cell.titleLabel.text = recomendMvList[index].title
                if recomendMvList[index].time == "" {
                    cell.timeLabel.isHidden = true
                }else{
                    cell.timeLabel.isHidden = false
                    cell.timeLabel.text = recomendMvList[index].time
                }
                cell.numlabel.isHidden = true
                let imgUrl: NSURL = NSURL(string: recomendMvList[index].imgUrl!)!
                cell.imageView.sd_setImage(with: imgUrl as URL)
                let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
                let context:NSManagedObjectContext = appDelegate.managedObjectContext
                let fetchRequest:NSFetchRequest<MVModel> = MVModel.fetchRequest()
                let predicate = NSPredicate(format:"%K = %@","videoID",recomendMvList[index].videoID!)
                fetchRequest.predicate = predicate
                let fetchData = try! context.fetch(fetchRequest)
                if(!fetchData.isEmpty){
                    cell.checkmark.isHidden = false
                } else {
                    cell.checkmark.isHidden = true
                }
                return cell
            }
        }
    }
    //  タップされた時
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView.tag == 0 {
            if seachTextField.text != "" {
                seachTextField.text = seachTextField.text! + " " + recomendWardList[indexPath.row]
            }else{
                seachTextField.text = recomendWardList[indexPath.row]
            }
            seachTextField.becomeFirstResponder()
        }else{
            var index = indexPath.row
            if ADApearFlg(){
                index = indexPath.row - 1
            }
            if index > -1 {
                let cell = collectionView.cellForItem(at: indexPath)
                if cell is RecommendMVCollectionViewCell{
                    nowYoutubeVideoID = recomendMvList[index].videoID!
                    youtubeVideoTitle = recomendMvList[index].title!
                    youtubeVideoThumbnailUrl = recomendMvList[index].imgUrl!
                    youtubeVideoTime = recomendMvList[index].time!
                    if UserDefaults.standard.object(forKey: "searchToMVNum") == nil{
                        SEARCH_TO_MV = 1
                        UserDefaults.standard.set(SEARCH_TO_MV, forKey: "searchToMVNum")
                    }else{
                        SEARCH_TO_MV = UserDefaults.standard.integer(forKey: "searchToMVNum") + 1
                        UserDefaults.standard.set(SEARCH_TO_MV, forKey: "searchToMVNum")
                    }
                    if SEARCH_MV_AD_INTERVAL != 0 && SEARCH_TO_MV % SEARCH_MV_AD_INTERVAL == 0{
                        if ADApearFlg() {
                            if adDialogLoader.isLoading == false {
                                UIApplication.shared.keyWindow?.rootViewController!.view.addSubview(popupView)
                                dialogPopUpAnimesion(view: popupView.baseView)
                            }
                        }
                    }
                    performSegue(withIdentifier: "toYoutubePlayer",sender: "")
                }
            }
        }
    }
    /* 長押しした際に呼ばれるメソッド */
    @objc func recommendLongPressed(recognizer: UILongPressGestureRecognizer) {
        let point: CGPoint = recognizer.location(in: recommendMVCollectView)
        let indexPath = recommendMVCollectView.indexPathForItem(at: point)
        if let indexPath = indexPath {
            var index = indexPath.row
            if ADApearFlg(){
                index = indexPath.row - 1
            }
            if index < 0 {
                return
            }
            if recognizer.state == UIGestureRecognizer.State.began {
                let cell = recommendMVCollectView.cellForItem(at: indexPath) as? RecommendMVCollectionViewCell
                if (cell?.checkmark.isHidden)!{
                    // アラートを作成
                    let alert = UIAlertController(
                        title: localText(key:"okiniiri_regist_title"),
                        message: localText(key:"okiniiri_regist_body"),
                        preferredStyle: .alert)
                    
                    // アラートにボタンをつける
                    alert.addAction(UIAlertAction(title:localText(key:"btn_ok"), style: .default, handler: { action in
                        // 登録する
                        let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
                        let MVContext:NSManagedObjectContext = appDelegate.managedObjectContext
                        let MVEntity = NSEntityDescription.entity(forEntityName: "MVModel", in: MVContext)
                        let MVlistModel = NSManagedObject(entity:MVEntity!,insertInto:MVContext) as! MVModel
                        
                        // 登録されているMVModel数を取得
                        let fetchRequest:NSFetchRequest<MVModel> = MVModel.fetchRequest()
                        let fetchData = try! MVContext.fetch(fetchRequest)
                        if(!fetchData.isEmpty){
                            MVlistModel.indicatoryNum = Int16(fetchData.count)
                        }else{
                            MVlistModel.indicatoryNum = 0
                        }
                        // 登録されている「お気に入り動画」数も更新
                        let appDelegateC:AppDelegate = UIApplication.shared.delegate as! AppDelegate
                        let contextC:NSManagedObjectContext = appDelegateC.managedObjectContext
                        let fetchRequestC:NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
                        let fetchDataC = try! contextC.fetch(fetchRequestC)
                        if(!fetchDataC.isEmpty){
                            for i in 0..<fetchDataC.count{
                                if fetchDataC[i].musicLibraryName == MV_LIST_NAME{
                                    if(!fetchData.isEmpty){
                                        fetchDataC[i].trackNum = Int16(fetchData.count)
                                    }else{
                                        fetchDataC[i].trackNum = 0
                                    }
                                }
                            }
                        }
                        
                        MVlistModel.videoID = recomendMvList[index].videoID!
                        MVlistModel.musicLibraryName = MV_LIST_NAME
                        MVlistModel.thumbnailUrl = recomendMvList[index].imgUrl!
                        MVlistModel.videoTitle = recomendMvList[index].title!
                        MVlistModel.videoTime = recomendMvList[index].time!
                        do{
                            try MVContext.save()
                            try contextC.save()
                            
                        }catch{
                            dlog(error)
                            return
                        }
                        iconPopUpAnimesion(view : cell!.checkmark)
                        // Firebaseに登録
                        setOkiniiriData(videoId:recomendMvList[index].videoID! ,categoryID:SETTING_NOW_CATEGORYID,
                                        title:recomendMvList[index].title! ,imageUrl: recomendMvList[index].imgUrl! ,time:recomendMvList[index].time! )
                    }))
                    alert.addAction(UIAlertAction(title: localText(key:"btn_cancel"), style: .default, handler: { action in
                        
                    }))
                    
                    self.present(alert, animated: true, completion: nil)
                }else{
                    // アラートを作成
                    let alert = UIAlertController(
                        title: localText(key:"okiniiri_delete_title"),
                        message: localText(key:"okiniiri_delete_body"),
                        preferredStyle: .alert)
                    
                    // アラートにボタンをつける
                    alert.addAction(UIAlertAction(title: localText(key:"btn_ok"), style: .default, handler: { action in
                        
                        //削除する
                        let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
                        let MVContext:NSManagedObjectContext = appDelegate.managedObjectContext
                        let fetchRequest:NSFetchRequest<MVModel> = MVModel.fetchRequest()
                        let predicate = NSPredicate(format:"%K = %@","videoID",recomendMvList[index].videoID!)
                        fetchRequest.predicate = predicate
                        let fetchData = try! MVContext.fetch(fetchRequest)
                        if(!fetchData.isEmpty){
                            for i in 0..<fetchData.count{
                                let deleteObject = fetchData[i] as MVModel
                                MVContext.delete(deleteObject)
                            }
                            
                        }
                        do{
                            try MVContext.save()
                            
                        }catch{
                            dlog(error)
                            return
                        }
                        // 登録されている「お気に入り動画」数も更新
                        let appDelegateB:AppDelegate = UIApplication.shared.delegate as! AppDelegate
                        let contextB:NSManagedObjectContext = appDelegateB.managedObjectContext
                        let fetchRequestB:NSFetchRequest<MVModel> = MVModel.fetchRequest()
                        let fetchDataB = try! contextB.fetch(fetchRequestB)
                        
                        let appDelegateC:AppDelegate = UIApplication.shared.delegate as! AppDelegate
                        let contextC:NSManagedObjectContext = appDelegateC.managedObjectContext
                        let fetchRequestC:NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
                        let fetchDataC = try! contextC.fetch(fetchRequestC)
                        if(!fetchDataC.isEmpty){
                            for i in 0..<fetchDataC.count{
                                if fetchDataC[i].musicLibraryName == MV_LIST_NAME{
                                    if(!fetchDataB.isEmpty){
                                        fetchDataC[i].trackNum = Int16(fetchDataB.count)
                                    }else{
                                        fetchDataC[i].trackNum = 0
                                    }
                                }
                            }
                        }
                        do{
                            try contextC.save()
                            
                        }catch{
                            dlog(error)
                            return
                        }
                        iconPopDownAnimesion(view : cell!.checkmark)
                    }))
                    alert.addAction(UIAlertAction(title: localText(key:"btn_cancel"), style: .default, handler: { action in
                        
                    }))
                    
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }else{
            dlog("long press on table view")
        }
    }
}


extension SearchViewController: WKUIDelegate, WKNavigationDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {

        let disableCalloutScriptString = "document.addEventListener('DOMContentLoaded', function() { let noneItem = document.getElementsByClassName('youtubeのクラス'); for (let i = 0; i < noneItem.length; i++) { noneItem[i].style.display = 'none'; }});"
        
        let disableCalloutScript = WKUserScript(source: disableCalloutScriptString, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        let controller = WKUserContentController()
        controller.addUserScript(disableCalloutScript)
        let viewConfiguration = WKWebViewConfiguration()
        viewConfiguration.userContentController = controller //上記の操作禁止を反映

        return WKWebView(frame: webView.frame, configuration: viewConfiguration)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Swift.Void) {
        recommendMvHiddenFlg = true
        recommendMVView.isHidden = judgeDisplayRecommendMV(flg : true)
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
        searchResultTableView.isHidden = true
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
        dlog("リダイレクト")
    }
}
