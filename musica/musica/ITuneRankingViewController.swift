//
//  ITuneRankingViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2017/06/24.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import SDWebImage
import Reachability
import AVFoundation
import GoogleMobileAds
import DGElasticPullToRefresh
import UserNotifications

class ITuneRankingViewController: UIViewController ,UITableViewDelegate,FullScreenContentDelegate, UITableViewDataSource, AVAudioPlayerDelegate, APVAdManagerDelegate ,FADDelegate{

    /*
     広告関連
    */
    @IBOutlet weak var adView: UIView!
    var adHederLoader: AdLoader!
    let myADViewDialog: UIView = UIView()
    //var interstitial: GADInterstitial!
    var nativeAdDialogView: NativeAdView?
    
    let popupView:PopUpAdDialog = UINib(nibName: "PopUpDialog", bundle: nil).instantiate(withOwner: self,options: nil)[0] as! PopUpAdDialog
    var nativeAdView: NativeAdView!
    var heightConstraint : NSLayoutConstraint?
    var size = CGSize()
    let myADView: UIView = UIView()
    let myRecommendADView: UIView = UIView()
    var subContentView = UIView()
    var aPVAd: UIView = UIView()
    var aPVAdManager: APVAdManager?
    
    @IBOutlet weak var bannerView: BannerView!
    /*
     ボタン関連
     */
    @IBOutlet weak var selectViewModeBtn: UISegmentedControl!
    @IBOutlet weak var reloadBtn: UIButton!
    
    /*
     ランキングtable関連
     */
    @IBOutlet weak var iTunesRankingTableView: UITableView!
    @objc dynamic var itemsArray = [AnyObject]()
    var cellNum : Int = 0
    var keyWard : String = ""
    var artistName : String = ""
    var musicName : String = ""
    var itunesUrl : String = ""
    var itunesArtwork : String = ""
    
    /*
     切り替えView
     */
    @IBOutlet weak var waitView: UIView!
    @IBOutlet weak var errorView: UIView!
    @IBOutlet weak var errTextView: UITextView!
    /*
     オフライン検知
     */
    let reachability = try! Reachability()

    override func viewDidLoad() {
        super.viewDidLoad()
        UNUserNotificationCenter.current().requestAuthorization(
        options: [.alert, .sound, .badge]){
            (granted, _) in
            if granted{
                setLocalPush()
            }else{
                deleteLocalPush(pushID:LOCAL_PUSH_RANKING_ID)
            }
        }

        selectViewModeBtn.selectedSegmentIndex = 1
        // tableViewカスタマイズ
        if #available(iOS 11.0, *) {
            let loadingView = DGElasticPullToRefreshLoadingViewCircle()
            reloadBtn.setTitleColor(UIColor.lightGray, for: .highlighted)
            // PullToRefresh
            loadingView.tintColor = UIColor.white
            iTunesRankingTableView.dg_addPullToRefreshWithActionHandler({ [weak self] () -> Void in
                self?.seachYouTubeVideoInformation(viewMode : (self?.selectViewModeBtn.selectedSegmentIndex)!, waitMode: false)
                self?.iTunesRankingTableView.dg_stopLoading()
                self?.adHederLoader.load(Request())
                }, loadingView: loadingView)
        }
        
        // ここでヘッダーのサイズを指定
        size = CGSize(width: myAppFrameSize.width, height: myAppFrameSize.width * 11 / 16 )
        
        // Do any additional setup after loading the view.
        self.addObserver(self, forKeyPath: "itemsArray", options: [.old, .new], context: nil)
        
        seachYouTubeVideoInformation(viewMode : selectViewModeBtn.selectedSegmentIndex, waitMode: true)
        errorView.isHidden = true
        
        popupView.frame = CGRect(x: 0, y: 0, width: myAppFrameSize.width, height: myAppFrameSize.height)
        popupView.removeAdBtn.setTitle(REMOVE_AD, for: .normal)
        popupView.clloseBtn.setTitle(MESSAGE_CLOSE, for: .normal)
        
        myADViewDialog.frame =  CGRect(x: 0, y: 0 , width: myAppFrameSize.width - 32 ,height:(myAppFrameSize.width - 32) * 15/32 + 70)
        popupView.baseAdView.addSubview(myADViewDialog)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
        
        iTunesRankingTableView.dg_setPullToRefreshFillColor(NAVIGATION_PTR_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.RANKING.rawValue])
        iTunesRankingTableView.dg_setPullToRefreshBackgroundColor(iTunesRankingTableView.backgroundColor!)
        // 広告の準備
        //interstitial = createAndLoadInterstitial()
        // 課金情報の更新
        if UserDefaults.standard.object(forKey: "kakin") == nil{
            UserDefaults.standard.set(false, forKey: "kakin")
            KAKIN_FLG = false
        }else{
            KAKIN_FLG = UserDefaults.standard.bool(forKey: "kakin")
        }
        
        if AD_DISPLAY_RANKING_BANNER {
            bannerView.adUnitID = ADMOB_BANNER_ADUNIT_ID
            bannerView.rootViewController = self
            custumLoadBannerAd(bannerView: self.bannerView,setBannerView:self.view)
        }else{
            bannerView.isHidden = true
        }
        let nibObjectsDialog = Bundle.main.loadNibNamed("PopUpAdView", owner: nil, options: nil)
        let adViewDialog = (nibObjectsDialog?.first as? NativeAdView)!
        setAdView(adViewDialog,adUnitID: ADMOB_NATIVE_ADVANCE_DIALOG_RECOMMEND)
        let nibObjects = Bundle.main.loadNibNamed("UnifiedNativeAdView", owner: nil, options: nil)
        let adView = (nibObjects?.first as? NativeAdView)!
        setAdView(adView,adUnitID: ADMOB_NATIVE_ADVANCE_RANKING)
        iTunesRankingTableView.reloadData()
        // バックグラウンドでも再生できるカテゴリに設定する
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [])
            try session.setActive(true)
        } catch  {
            showAlertMsgOneOkBtn(title: ITUNE_RANKING_ERR,messege: ITUNE_RANKING_ERR_SESSION)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.reachabilityChanged),name: ReachabilityChangedNotification,object: reachability)
        do{
            try reachability.startNotifier()
        }catch{
            print("could not start reachability notifier")
        }
        if UserDefaults.standard.object(forKey: "rankingLookCount") == nil{
            UserDefaults.standard.set(RANKING_LOOK_NUM, forKey: "rankingLookCount")
        }else{
            RANKING_LOOK_NUM = UserDefaults.standard.integer(forKey: "rankingLookCount") + 1
            UserDefaults.standard.set(RANKING_LOOK_NUM, forKey: "rankingLookCount")
        }
        // 条件を満たしていたら、広告表示
        if RANKING_AD_INTERVAL != 0{
            if RANKING_LOOK_NUM % RANKING_AD_INTERVAL == 0{
                if ADApearFlg() {
                    if adDialogLoader.isLoading == false {
                        UIApplication.shared.keyWindow?.rootViewController!.view.addSubview(popupView)
                        dialogPopUpAnimesion(view: popupView.baseView)
                    }
                }
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil, completion: { (context) -> Void in
        });
    }
    
    // 監視対象の値に変化があった時に呼ばれる
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        // Viewの更新はメインスレッドで実行
        DispatchQueue.main.async {
            self.iTunesRankingTableView.reloadData()
            self.waitView.isHidden = true
            self.errorView.isHidden = true
        }
        
    }

    /*******************************************************************
     ランキング情報取得処理
     *******************************************************************/
    func seachYouTubeVideoInformation(viewMode : Int ,waitMode : Bool) {
        if waitMode {
            waitView.isHidden = false
        }
        checkOffline()
        let apiMostPlayedMusic: String = dicideRankingUrl(type:MOST_PLAYED_MUSIC)
        let apiMostPlayedVideo: String = dicideRankingUrl(type:MOST_PLAYED_VIDEO)
        
        // 取得するランキングを設定
        var apiUrl = ""
        switch viewMode {
        case MOST_PLAYED_MUSIC:
            apiUrl = apiMostPlayedMusic
        case MOST_PLAYED_VIDEO:
            apiUrl = apiMostPlayedVideo
        default:
            apiUrl = apiMostPlayedMusic
        }
        
        // request to iTune api feed
        let session = URLSession.shared
        var jsonResult : NSDictionary = NSDictionary()
        let task = session.dataTask(with: URLRequest(url: URL(string: apiUrl)!), completionHandler: {
            (data, response, error) in
            if data == nil{
                DispatchQueue.main.async {
                    self.waitView.isHidden = true
                    self.errorView.isHidden = false
                }
                return
            }
            do {
                if let _jsonResult: NSDictionary = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? NSDictionary {
                    jsonResult = _jsonResult
                }else{
                    self.waitView.isHidden = true
                    self.errorView.isHidden = false
                    return
                }
                let iTuneFeedJson = jsonResult.object(forKey: "feed")  as! NSDictionary
                self.itemsArray = (iTuneFeedJson.object(forKey: "results") as! NSArray) as [AnyObject]
            } catch {
                DispatchQueue.main.async {
                    self.waitView.isHidden = true
                    self.errorView.isHidden = false
                }
            }
        })
        task.resume()
    }
    
    /*******************************************************************
     ランキングtable更新処理
     *******************************************************************/
    // セクションの個数
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    // セクション内の行数
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // 配列webListの値の個数
        if section == 0 {
            return 0
        } else {
            return itemsArray.count // 行数＋フッター数
        }
    }
    
    // tableフッターの高さを返却
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == 0 {
            if ADApearFlg() == false {
                adView.isHidden = true
                return 0
            }
            adView.isHidden = false
            adView.addSubview(myADView)
            return CGFloat(Int(myAppFrameSize.width) * 11 / 16 + 4)
        } else {
            if AD_DISPLAY_RANKING_BANNER{
                bannerView.isHidden = false
                return bannerView.frame.height
            }else{
                bannerView.isHidden = true
                return 0
            }
        }
    }
    // tableフッターを返却
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == 1 {
            if AD_DISPLAY_RANKING_BANNER{
                let uiView = UIView()
                return uiView
            }else{
                bannerView.isHidden = true
                return UIView()
            }
        } else {
            return UIView()
        }
    }
    // テーブルヘッダーの高さをかえします
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
    
    // テーブルヘッダーをかえします（フッターだけどヘッダーとして利用）
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return UIView()
    }
    
    // セルを作る
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "iTuneContentsCell", for: indexPath) as! iTuneRankingTableViewCell
        let items: NSDictionary = itemsArray[(indexPath as NSIndexPath).row] as! NSDictionary
        let artwork = items.object(forKey: "artworkUrl100") as! NSString
        // 画像の表示調整
        cell.iTuneContentsImageView.contentMode = .scaleAspectFit
        var imgUrl: NSURL = NSURL()
        let checkUrl = imgUrl
        //画像データに変換
        if let _imgUrl: NSURL = NSURL(string: artwork as String){
            imgUrl = _imgUrl
        }
        if imgUrl == checkUrl{
            cell.iTuneContentsImageView.image = UIImage(named: "onpu_BL")
        }else{
            cell.iTuneContentsImageView.sd_setImage(with: imgUrl as URL)
        }
        cell.iTuneContentsTitle.text = items.object(forKey: "name") as? String
        cell.iTuneContentsArtist.text = items.object(forKey: "artistName") as? String
        cell.iTuneContentsNumLabel.text = String((indexPath as NSIndexPath).row + 1)

        fadeInRanDomAnimesion(view : cell.iTuneContentsImageView)
        return cell
    }
    /* UITableViewDelegateデリゲートメソッド */
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath as IndexPath, animated: true)
        guard let items: NSDictionary = itemsArray[(indexPath as NSIndexPath).row] as? NSDictionary else {
            showAlertMsgOneOkBtn(title: ITUNE_RANKING_ERR,messege: ITUNE_RANKING_ERR_CANT_SHOW_CONTENTS)
            return
        }
        var title = ""
        var artist = ""
        var url = ""
        var artworkUrl100 = ""
        if let _title: String = items.object(forKey: "name") as? String {
            title = _title
            keyWard = title + " "
        }
        if let _artist: String = items.object(forKey: "artistName") as? String {
            artist = _artist
            keyWard = keyWard + artist
        }
        if let _url: String = items.object(forKey: "url") as? String {
            url = _url
        }
        if let _artworkUrl100: String = items.object(forKey: "artworkUrl100") as? String {
            artworkUrl100 = _artworkUrl100
        }
        artistName = artist
        musicName = title
        itunesUrl = url
        itunesArtwork = artworkUrl100
        if UserDefaults.standard.object(forKey: "rankingLookCount") == nil{
            UserDefaults.standard.set(RANKING_LOOK_NUM, forKey: "rankingLookCount")
        }else{
            RANKING_LOOK_NUM = UserDefaults.standard.integer(forKey: "rankingLookCount") + 1
            UserDefaults.standard.set(RANKING_LOOK_NUM, forKey: "rankingLookCount")
        }
        // 条件を満たしていたら、広告表示
        if RANKING_AD_INTERVAL != 0{
            if RANKING_LOOK_NUM % RANKING_AD_INTERVAL == 0{
                if ADApearFlg() {
                    if adDialogLoader.isLoading == false {
                        UIApplication.shared.keyWindow?.rootViewController!.view.addSubview(popupView)
                        dialogPopUpAnimesion(view: popupView.baseView)
                    }
                }
            }
        }
        performSegue(withIdentifier: "toContentsList",sender: "")
    }

    /*******************************************************************
     ボタンタップ時処理
     *******************************************************************/
    // 選択が変更された際の処理
    @IBAction func selectViewModeBtnTapped(_ sender: Any) {
        self.adHederLoader.load(Request())
        if UserDefaults.standard.object(forKey: "rankingLookCount") == nil{
            UserDefaults.standard.set(RANKING_LOOK_NUM, forKey: "rankingLookCount")
        }else{
            RANKING_LOOK_NUM = UserDefaults.standard.integer(forKey: "rankingLookCount") + 1
            UserDefaults.standard.set(RANKING_LOOK_NUM, forKey: "rankingLookCount")
        }
        // 条件を満たしていたら、広告表示
        if RANKING_AD_INTERVAL != 0{
            if RANKING_LOOK_NUM % RANKING_AD_INTERVAL == 0{
                if ADApearFlg() {
                    if adDialogLoader.isLoading == false {
                        UIApplication.shared.keyWindow?.rootViewController!.view.addSubview(popupView)
                        dialogPopUpAnimesion(view: popupView.baseView)
                    }
                }
            }
        }
        seachYouTubeVideoInformation(viewMode : selectViewModeBtn.selectedSegmentIndex, waitMode: true)
    }
    // 再読み込みボタンが押された際の処理
    @IBAction func reloadBtnTapped(_ sender: Any) {
        self.adHederLoader.load(Request())
        seachYouTubeVideoInformation(viewMode : selectViewModeBtn.selectedSegmentIndex, waitMode: true)
    }
    
    // チャートカントリー選択ボタンが押された時の処理
    @IBAction func chartCountrySelectBtnTapped(_ sender: Any) {
        let actionSheet = UIAlertController(title: localText(key:"ranking_change_country_title"), message: localText(key:"ranking_change_country_body"), preferredStyle: UIAlertController.Style.actionSheet)
        
        let action1 = setActionsheet(title : localText(key:"ranking_country_jp"))
        let action2 = setActionsheet(title : localText(key:"ranking_country_ame"))
        let action3 = setActionsheet(title : localText(key:"ranking_country_trk"))
        let action4 = setActionsheet(title : localText(key:"ranking_country_egi"))
        let action5 = setActionsheet(title : localText(key:"ranking_country_kan"))
        let action6 = setActionsheet(title : localText(key:"ranking_country_tyu"))
        let action7 = setActionsheet(title : localText(key:"ranking_country_tai"))
        let action8 = setActionsheet(title : localText(key:"ranking_country_spe"))
        
        let cancel = UIAlertAction(title: localText(key:"btn_cancel"), style: UIAlertAction.Style.cancel, handler: {
            (action: UIAlertAction!) in
            print("キャンセルをタップした時の処理")
        })
        
        actionSheet.addAction(action1)
        actionSheet.addAction(action2)
        actionSheet.addAction(action3)
        actionSheet.addAction(action4)
        actionSheet.addAction(action5)
        actionSheet.addAction(action6)
        actionSheet.addAction(action7)
        actionSheet.addAction(action8)
        actionSheet.addAction(cancel)
        
        self.present(actionSheet, animated: true, completion: nil)
    }
    /*******************************************************************
     ランキング取得URL生成処理
     *******************************************************************/
    func dicideRankingUrl(type:Int) -> String{
        var urlStr = ""
        switch type {
        case MOST_PLAYED_MUSIC:
            switch SETTING_CONTRY_CODE {
            case CONTRY_CODE_JP,CONTRY_CODE_US,CONTRY_CODE_GB,CONTRY_CODE_TH,CONTRY_CODE_ES,CONTRY_CODE_TR:
                urlStr = "https://rss.applemarketingtools.com/api/v2/\(SETTING_CONTRY_CODE)/music/most-played/50/songs.json"
            case CONTRY_CODE_KR,CONTRY_CODE_CN:
                urlStr = "https://rss.applemarketingtools.com/api/v2/\(SETTING_CONTRY_CODE)/music/most-played//50/songs.json"
            default: break
            }
        case MOST_PLAYED_VIDEO:
            switch SETTING_CONTRY_CODE {
            case CONTRY_CODE_JP,CONTRY_CODE_US,CONTRY_CODE_GB,CONTRY_CODE_TH,CONTRY_CODE_ES,CONTRY_CODE_TR:
                urlStr = "https://rss.applemarketingtools.com/api/v2/\(SETTING_CONTRY_CODE)/music/most-played/50/music-videos.json"
            
            case CONTRY_CODE_KR,CONTRY_CODE_CN:
                urlStr = "https://rss.applemarketingtools.com/api/v2/\(SETTING_CONTRY_CODE)/music/most-played/50/music-videos.json"
            default: break
            }
        default: break
        }
        return urlStr
    }
    /*******************************************************************
     ネットワーク確認処理
     *******************************************************************/
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
    func checkOffline(){
        if reachability.isReachable {
            print("online")
        }else{
            print("offlone")
            waitView.isHidden = true
            errorView.isHidden = false
            return
        }
    }
    /*******************************************************************
     ActionSheetのラッパー
     *******************************************************************/
    // ActionSheetのラッパー
    func setActionsheet(title: String ) -> UIAlertAction{
        
        var style = UIAlertAction.Style.default
        var selectContry = ""
        switch title {
        case localText(key:"ranking_country_jp"):
            selectContry = CONTRY_CODE_JP
            if SETTING_CONTRY_CODE == CONTRY_CODE_JP{
                style = UIAlertAction.Style.destructive
            }
        case localText(key:"ranking_country_ame"):
            selectContry = CONTRY_CODE_US
            if SETTING_CONTRY_CODE == CONTRY_CODE_US{
                style = UIAlertAction.Style.destructive
            }
        case localText(key:"ranking_country_trk"):
            selectContry = CONTRY_CODE_TR
            if SETTING_CONTRY_CODE == CONTRY_CODE_TR{
                style = UIAlertAction.Style.destructive
            }
        case localText(key:"ranking_country_egi"):
            selectContry = CONTRY_CODE_GB
            if SETTING_CONTRY_CODE == CONTRY_CODE_GB{
                style = UIAlertAction.Style.destructive
            }
        case localText(key:"ranking_country_kan"):
            selectContry = CONTRY_CODE_KR
            if SETTING_CONTRY_CODE == CONTRY_CODE_KR{
                style = UIAlertAction.Style.destructive
            }
        case localText(key:"ranking_country_tyu"):
            selectContry = CONTRY_CODE_CN
            if SETTING_CONTRY_CODE == CONTRY_CODE_CN{
                style = UIAlertAction.Style.destructive
            }
        case localText(key:"ranking_country_tai"):
            selectContry = CONTRY_CODE_TH
            if SETTING_CONTRY_CODE == CONTRY_CODE_TH{
                style = UIAlertAction.Style.destructive
            }
        case localText(key:"ranking_country_spe"):
            selectContry = CONTRY_CODE_ES
            if SETTING_CONTRY_CODE == CONTRY_CODE_ES{
                style = UIAlertAction.Style.destructive
            }
        default:
            selectContry = CONTRY_CODE_JP
        }
        
        let action = UIAlertAction(title: title, style: style, handler: {
            (action: UIAlertAction!) in
            SETTING_CONTRY_CODE = selectContry
            self.seachYouTubeVideoInformation(viewMode : self.selectViewModeBtn.selectedSegmentIndex,waitMode: true)
        })
        return action
    }
    
    /*******************************************************************
     広告関連の処理
     *******************************************************************/
    // AmazonAdViewDelegate APVAdManagerDelegate で使う
    func viewControllerForPresentingModalView() -> UIViewController! {
        return self
    }
    // 動画の再生準備完了通知です。
    func onReady(toPlayAd ad: APVAdManager!, for nativeAd: APVNativeAd!) {
        myADView.addSubview(aPVAd)
        ad.showAd(for: aPVAd)
    }
    func adViewDidFail(toLoad view: AmazonAdView!, withError: AmazonAdError!) -> Void {}
    func adViewWillExpand(_ view: AmazonAdView!) -> Void {}
    func adViewDidCollapse(_ view: AmazonAdView!) -> Void {}
    // Five
    var fadDelegate:FADDelegate!
    func fiveAdDidReplay(_ ad: FADAdInterface!) {    }
    func fiveAdDidViewThrough(_ ad: FADAdInterface!) {}
    func fiveAdDidResume(_ ad: FADAdInterface!) {}
    func fiveAdDidPause(_ ad: FADAdInterface!) {}
    func fiveAdDidStart(_ ad: FADAdInterface!) {}
    func fiveAdDidClose(_ ad: FADAdInterface!) {}
    func fiveAdDidClick(_ ad: FADAdInterface!) {}
    func fiveAd(_ ad: FADAdInterface!, didFailedToReceiveAdWithError errorCode: FADErrorCode) {}
    func fiveAdDidLoad(_ ad: FADAdInterface!) {}
    /*******************************************************************
     画面遷移時処理
     *******************************************************************/
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //Track 一覧画面へ
        if segue.identifier == "toContentsList" {
            let secondVc = segue.destination as! iTuneRankingContentsListViewController
            // 値を渡す
            secondVc.searchTitleWord = keyWard
            secondVc.searchArtist = artistName
            secondVc.searchMusic = musicName
            secondVc.itunesUrl = itunesUrl
            secondVc.itunesArtwork = itunesArtwork
            secondVc.searchWord = keyWard//.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? "エンコードできませんでした"
        }
    }
    // オブジェクト破棄時に監視を解除
    deinit {
        self.removeObserver(self, forKeyPath: "itemsArray")
        //イベントリスナーの削除
        NotificationCenter.default.removeObserver(self)
    }
    
}
