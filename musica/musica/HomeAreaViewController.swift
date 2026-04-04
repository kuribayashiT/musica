//
//  HomeAreaViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2017/04/18.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import MediaPlayer
import AVFoundation
import CoreData
import AdSupport
import GoogleMobileAds
import Instructions
import DGElasticPullToRefresh
import SDWebImage
import SwiftGifOrigin
import SWTableViewCell
import Firebase
import YoutubePlayer_in_WKWebView


class HomeAreaViewController: UIViewController, UITableViewDataSource, UITableViewDelegate ,MPMediaPickerControllerDelegate, AVAudioPlayerDelegate ,  CoachMarksControllerDataSource, CoachMarksControllerDelegate, APVAdManagerDelegate,FADDelegate, SWTableViewCellDelegate ,GADRewardedAdDelegate{
    /*
     チュートリアル
     */
    let coachMarksController = CoachMarksController()
    let myADView: UIView = UIView()
    let myViewOKINIIRIAREA: UIView = UIView()
    let myTableCellView: UIView = UIView()
    let myViewtabViewSearchItem : UIView = UIView()
    let myViewtabViewRankingItem : UIView = UIView()
    let myViewtabViewSettingItem : UIView = UIView()
    var tabSize =  CGSize()
    @IBOutlet weak var corchMusicarea: UIView!
    var musiclibraryExtentFlg = true
    
    /*
     広告関連
     */
    var ADtimer : Timer!
    var splashtimer = Timer()
    var subContentView = UIView()
    var aPVAd: UIView = UIView(frame: CGRect(x:0,y: 100,width: 320,height: 180))
    var aPVAdManager: APVAdManager?
    var adLoader: GADAdLoader!
    var nativeAdView: GADUnifiedNativeAdView!
    var heightConstraint : NSLayoutConstraint?
    
    /*
     ボタン関連
     */
    @IBOutlet weak var helpBtnViewArea: UIView!
    @IBOutlet weak var rewardADBtn: UIButton!
    @IBOutlet weak var rewardADAre: UIBarButtonItem!
    var nowBarBtn = 0
    /*
     table関連
     */
    // youtubeView
    let youtubeView = WKYTPlayerView()
    @IBOutlet weak var musictableview: UITableView!
    @IBOutlet weak var contentsNumLabel: UILabel!
    // セルに表示するデータ
    var musicLibraryList: [(musicLibraryName:String, trackNum:Int , iconName : String , iconColorName : String)] = []
    var selectMusicLibraryName : String = ""
    var selectMusicLibraryImageColorName : String = ""
    var selectMusicLibraryIconName : String = ""
    var newMusicLibraryCode : Int = 0
    var registBtnCell = 0
    var playedFlg = false
    var ADwaitView = UIView()
    var rewardedAd: GADRewardedAd?
    var remoteConfig: RemoteConfig!
    let mMusicController = MusicController()    
    override func viewDidLoad() {
        super.viewDidLoad()

        remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        remoteConfig.setDefaults(fromPlist: "RemoteConfigDefaults")
        remoteConfig.configSettings = settings
        
        remoteConfig.fetch(withExpirationDuration: TimeInterval(10)) { (status, error) -> Void in
          if status == .success {
            self.remoteConfig.activate() { (changed, error) in
                setUpRemoteconfig(vc:self)
            }
//            
//            self.remoteConfig.activate(completionHandler: { (error) in
//                setUpRemoteconfig(vc:self)
//            })
          }
        }
        
        ADwaitView = self.createView()
        self.tabBarController?.view.addSubview(ADwaitView)
        // 端末によるサイズの計算とviewの設定
        let size = CGSize(width: myAppFrameSize.width, height: myAppFrameSize.width * 9 / 16)
        musictableview.sectionHeaderHeight = myAppFrameSize.height
        // ここでタブのサイズを指定
        tabSize = CGSize(width: size.width / 5, height: (tabBarController?.tabBar.frame.size.height)!)
        myViewtabViewSearchItem.frame = CGRect(x:  Int(tabSize.width) * 2, y: Int(UIScreen.main.bounds.size.height) -  Int(tabSize.height), width: Int(tabSize.width),height: Int(tabSize.height))
        myViewtabViewRankingItem.frame = CGRect(x: Int(tabSize.width) * 1, y: Int(UIScreen.main.bounds.size.height) -  Int(tabSize.height) , width: Int(tabSize.width),height: Int(tabSize.height))
        myViewtabViewSettingItem.frame = CGRect(x: Int(tabSize.width) * 4, y: Int(UIScreen.main.bounds.size.height) -  Int(tabSize.height) , width: Int(tabSize.width),height: Int(tabSize.height))
        myViewtabViewSearchItem.isUserInteractionEnabled = false
        myViewtabViewRankingItem.isUserInteractionEnabled = false
        myViewtabViewSettingItem.isUserInteractionEnabled = false

        // チュートリアル
        self.coachMarksController.dataSource = self
        coachMarksController.overlay.blurEffectStyle = UIBlurEffect.Style(rawValue: 2) // ボカシ具合
        coachMarksController.overlay.isUserInteractionEnabled = true

        // tableViewのデザイン設定
        musictableview.estimatedRowHeight = 130
        musictableview.rowHeight = CGFloat(CELL_ROW_HEIGT_MIDDLE)
        
        // tableヘッダーのサイズを指定
        musictableview.sectionHeaderHeight = size.height
        
        // お気に入りのサイズを確定
        myViewOKINIIRIAREA.frame = CGRect(x: 0 , y: 0, width: Int(myAppFrameSize.width),height: CELL_ROW_HEIGT_MIDDLE)

        // 長押し時の挙動を登録
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.cellLongPressed))
        longPressRecognizer.allowableMovement = 15
        longPressRecognizer.minimumPressDuration = 0.6
        musictableview.addGestureRecognizer(longPressRecognizer)
        
        // PullToRefresh時の処理登録
        if #available(iOS 11.0, *) {
            let loadingView = DGElasticPullToRefreshLoadingViewCircle()
            loadingView.tintColor = UIColor.white
            musictableview.dg_addPullToRefreshWithActionHandler({ [weak self] () -> Void in
                self?.musictableview.reloadData()
                self?.musictableview.dg_stopLoading()
                self?.adLoader.load(GADRequest())
                }, loadingView: loadingView)
            musictableview.dg_setPullToRefreshFillColor(UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 0.5))
            musictableview.dg_setPullToRefreshBackgroundColor(musictableview.backgroundColor!)
        }
        // AD(Admob Five) setup
        //GADRewardBasedVideoAd.sharedInstance().delegate = self
        splashtimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: { (timer) in
            splashViewAnimation(mainView: self.tabBarController!.view, splashView: self.ADwaitView,logo: self.ADwaitView.subviews[0] as! UIImageView)
            if startAlert(vc:self) == false {
                if SETTING_STARTUP_NUM % 4 == 0{
                    //広告表示？？
                }
            }
        })
        if userDefaultInt(key:"youtube_mode") == 0 {
            YOUTUBE_PLAYER_FLG = false
        }else if userDefaultInt(key:"youtube_mode") == 1 {
            YOUTUBE_PLAYER_FLG = true
        }else{
            YOUTUBE_PLAYER_FLG = false
        }
        // recommend取得
        getRecommendMV()
        getRecommendWard()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        musictableview.reloadData()
    }
    /*******************************************************************
     画面描画時の処理
     *******************************************************************/
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if RESIST_LIBRARY_COMPLETE_FLG {
            showToastMsg(messege:MUSICLIBRALY_REGIST_COMP_TOAST,time:2.0, tab: COLOR_THEMA.HOME.rawValue,setVc:self.navigationController)
            RESIST_LIBRARY_COMPLETE_FLG = false
        }
        // 動画は一旦止める
        if AVPlayerViewControllerManager.shared.controller.player != nil {
            AVPlayerViewControllerManager.shared.controller.player?.pause()
        }
        fadeoutAnimesion(view : selectMusicView)
        LYRIC_RESULT_TEXT = ""
        // navigationbarの色設定
        self.navigationController?.navigationBar.isTranslucent = false
        //バーアイテムカラー
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]]
            self.navigationController!.navigationBar.standardAppearance = appearance
            self.navigationController!.navigationBar.scrollEdgeAppearance = self.navigationController!.navigationBar.standardAppearance
            self.navigationController!.navigationBar.tintColor = NAVIGATION_BTN_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
        } else {
            self.navigationController?.navigationBar.barTintColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
            self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]]
            self.navigationController!.navigationBar.tintColor = NAVIGATION_BTN_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
        }
        
        let nibObjects = Bundle.main.loadNibNamed("UnifiedNativeAdView", owner: nil, options: nil)
        let adView = (nibObjects?.first as? GADUnifiedNativeAdView)!
        setAdView(adView)
        if rewardADBtn != nil {
            if NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLACK.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLUE.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_RED.rawValue{
                rewardADBtn.layer.borderWidth = 1
                rewardADBtn.layer.borderColor = UIColor.darkGray.cgColor
                rewardADBtn.setTitleColor(UIColor(red: 0.0, green: 0.64, blue: 1.0, alpha: 1.0), for: .normal)
            }else{
                rewardADBtn.setTitleColor(UIColor(red: 0.0, green: 0.64, blue: 1.0, alpha: 1.0), for: .normal)
                rewardADBtn.layer.borderWidth = 0
                rewardADBtn.layer.borderColor = UIColor.clear.cgColor
            }
        }
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(self.handleInterruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        center.addObserver(self, selector: #selector(self.audioSessionRouteChanged(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        musictableview.dg_setPullToRefreshFillColor(NAVIGATION_PTR_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue])
        musictableview.dg_setPullToRefreshBackgroundColor(musictableview.backgroundColor!)
        // カラーテーマをUserPropatyにSet
        Analytics.setUserProperty(COLOR_THEMA_NAME[NOW_COLOR_THEMA], forName: "カラーテーマ")
        navigationItem.rightBarButtonItems = [makeQuestionBtn()]
        // 課金情報の更新
        if UserDefaults.standard.object(forKey: "kakin") == nil{
            UserDefaults.standard.set(false, forKey: "kakin")
            KAKIN_FLG = false
        }else{
            KAKIN_FLG = UserDefaults.standard.bool(forKey: "kakin")
        }
        rewardedAd = GADRewardedAd(adUnitID: ADMOB_REWARD_AD)
        rewardedAd?.load(GADRequest()) { error in
            if error != nil {
            // Handle ad failed to load case.
            } else {
            // Ad successfully loaded.
            }
        }
        
        //timer処理
        if ADtimer == nil || ADtimer.isValid == false {
            ADtimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { (timer) in
                self.checkRewardAD()
            })
        }
        //MusicLibraryのデータを読み込む(最新化)
        //musicLibraryList = []
        musicLibraryList = getNowMusicLibraryData()
        musictableview.isEditing = false
        musictableview.reloadData()
        
        if audioPlayer != nil {
            audioPlayer.delegate = self
            // バックグラウンドでも再生できるカテゴリに設定する
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [])
                try session.setActive(true)
            } catch  {
                // エラー処理
                //fatalError("カテゴリ設定失敗")
            }
            mMusicController.commandAllEnabled()
            commandCenter.nextTrackCommand.addTarget { (commandEvent) -> MPRemoteCommandHandlerStatus in
                self.nextMusicPlay()
                return MPRemoteCommandHandlerStatus.success
            }
            commandCenter.previousTrackCommand.addTarget { (commandEvent) -> MPRemoteCommandHandlerStatus in
                self.prevMusicPlay()
                return MPRemoteCommandHandlerStatus.success
            }
            commandCenter.playCommand.addTarget { (commandEvent) -> MPRemoteCommandHandlerStatus in
                self.play()
                return MPRemoteCommandHandlerStatus.success
            }
            commandCenter.pauseCommand.addTarget { (commandEvent) -> MPRemoteCommandHandlerStatus in
                self.stop()
                return MPRemoteCommandHandlerStatus.success
            }
        }
    }
    
    func makeEditBtn() -> UIBarButtonItem{
        let button = UIButton(type: UIButton.ButtonType.system)
        button.frame.size = CGSize(width: 80, height: 30)
        button.setTitleColor(UIColor.darkGray, for: UIControl.State.normal)
        if NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.BLACK.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_BLUE.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_RED.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLUE.rawValue {
            button.layer.borderWidth = 1.0
            button.layer.borderColor = UIColor.darkGray.cgColor
        }else{
            button.layer.borderWidth = 0
            button.layer.borderColor = UIColor.clear.cgColor
        }
        button.layer.cornerRadius = 5
        button.backgroundColor = UIColor.white
        button.addTarget(self, action: #selector(self.editDoneBtnTapped), for: UIControl.Event.touchUpInside)
        button.titleLabel?.font =  UIFont.systemFont(ofSize: 13 ,weight: UIFont.Weight.regular)
        button.setTitle(localText(key:"home_edit_comp"), for: UIControl.State.normal)
        let barButton = UIBarButtonItem(customView: button)
        nowBarBtn = 1
        return barButton
    }
    
    func makeQuestionBtn() -> UIBarButtonItem{
        let button = UIButton(type: UIButton.ButtonType.custom)
        button.frame.size = CGSize(width: 36, height: 36)
        let backImage = UIImage(named: "question")?.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
        button.setImage(backImage, for: UIControl.State.normal)
        button.addTarget(self, action: #selector(self.questionBtnTapped), for: UIControl.Event.touchUpInside)
        let barButton = UIBarButtonItem(customView: button)
        nowBarBtn = 0
        return barButton
    }
    // 画面描画後
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // "firstLaunch"に紐づく値がtrueなら(=初回起動)、値をfalseに更新して処理を行う
        let userDefault = UserDefaults.standard
        if userDefault.bool(forKey: "firstLaunch_Flg") {
            userDefault.set(false, forKey: "firstLaunch_Flg")
            
            let albumsQuery = MPMediaQuery.albums()
            print(albumsQuery)
        }
    }
    
    // 画面切り替え時
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.coachMarksController.stop(immediately: true)
        ADtimer.invalidate()
        // 編集完了ボタンの無効化
        navigationItem.rightBarButtonItems = [makeQuestionBtn()]
    }
    
    @IBAction func tutorialBtnTapped(_ sender: Any) {
        showToastMsg(messege:localText(key:"home_tutorial_label_tapped"),time:2.0, tab: COLOR_THEMA.HOME.rawValue)
    }
    /*******************************************************************
     table更新処理
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
            var musicLibraryListNum = 0
            if musicLibraryList.count == 1{
                musiclibraryExtentFlg = false
                musicLibraryListNum = musicLibraryList.count + 1
            }else{
                musiclibraryExtentFlg = true
                musicLibraryListNum = musicLibraryList.count + 1
            }
            musictableview.rowHeight = CGFloat(CELL_ROW_HEIGT_MIDDLE)
            return musicLibraryListNum// データ数
        }
        
    }
    // tableヘッダーの高さをかえします（フッターだけどヘッダーとして利用）
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == 0 {
            // 課金してたら広告エリア非表示
            if ADApearFlg() == false {
                return 0
            }else{
                return CGFloat(Int(myAppFrameSize.width) * 11 / 16 + 4)
            }
        } else {
            return 0
        }
    }
    
    // tableヘッダーの高さをかえします
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
    
    // tableヘッダーのViewをかえします
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            return UIView()
        } else {
            let headerView:UIView = UIView()
            return headerView
        }
    }
    // tableヘッダーにViewをセットしてかえします（フッターだけどヘッダーとして利用）
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == 0 {
            for subview in myADView.subviews {
                subview.removeFromSuperview()
            }
            if ADApearFlg() {
                let ImageV = UIImageView()
                ImageV.contentMode = .center
                ImageV.frame =  CGRect(x: 0, y: 0 , width: Int(myAppFrameSize.width),height: Int(myAppFrameSize.width) * 11 / 16 )
                ImageV.backgroundColor = darkModeNaviWhiteUIcolor()
                ImageV.image = UIImage(named: "homeicon_720")
                //myADView.backgroundColor = darkModeNaviWhiteUIcolor()
                myADView.addSubview(ImageV)
                return myADView
            }
            return UIView()
        } else {
            return UIView()
        }
    }
    
    // 1. 編集モードを許可するIndexPathの指定
    @objc func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool{
        // チュートリアルと、「お気に入り動画」「音楽ライブラリ登録ボタン」は編集不可
        if indexPath.row == 0{
            return false
        } else {
            if musicLibraryList.count == 1 && indexPath.row == 1 {
                return false
            }
            if musiclibraryExtentFlg == false && indexPath.row - 1 == musicLibraryList.count{
                return true // TODO
            }
            if indexPath.row == musicLibraryList.count{
                return false
            }
            return true
        }
    }
    // 2. ソートを許可するIndexPathの指定
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool{
        // チュートリアルと、「お気に入り動画」「音楽ライブラリ登録ボタン」は編集不可
        if indexPath.row == musicLibraryList.count {
            return false
            
        }
        if indexPath.row == 0 || indexPath.row == musicLibraryList.count {
            return false
        } else {
            return true
        }
    }
    
    func swipeableTableViewCellShouldHideUtilityButtons( onSwipe cell: SWTableViewCell) -> Bool{
        return true
    }
    
    func swipeableTableViewCell( _ cell: SWTableViewCell,canSwipeTo canSwipeToState: SWCellState) -> Bool{

        let cella = cell as! HomeTableViewCell
        if cella.libraryTitleLabel.text == localText(key:"home_okiniiri_title") {
            return false
        }else{
            return true
        }
    }
    
    // セルを作る
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if musiclibraryExtentFlg == false && indexPath.row - 1 == musicLibraryList.count{
            musictableview.rowHeight = UITableView.automaticDimension
            // ライブラリ登録ボタンのセルを表示する
            let cell = tableView.dequeueReusableCell(withIdentifier: "registerBtncell", for: indexPath) as! registerTableViewCell
            cell.selectionStyle = UITableViewCell.SelectionStyle.none
            if NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_BLUE.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_RED.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLUE.rawValue {
                cell.registerBtn.backgroundColor = NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
            }else if NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLACK.rawValue {
                cell.registerBtn.backgroundColor = BLACK
            }else{
                cell.registerBtn.backgroundColor = UIColor(red: 194/255, green: 47/255, blue: 101/255, alpha: 1.0)
            }
            tableView.tableFooterView = UIView()
            cell.separatorInset = UIEdgeInsets.init(top: 0, left: myAppFrameSize.width, bottom: 0, right: 0)
            
            cell.tutorialBtn.setTitle(localText(key:"home_tutorial_label"),for: .normal)
            if musiclibraryExtentFlg {
                cell.tutorialImg.isHidden = true
                cell.tutorialBtn.isHidden = true
            }else{
                cell.tutorialImg.isHidden = false
                cell.tutorialBtn.isHidden = false
            }
            fadeInRanDomAnimesion(view : cell.registerBtn)
            return cell
        }else if indexPath.row == musicLibraryList.count{
            musictableview.rowHeight = UITableView.automaticDimension
            // ライブラリ登録ボタンのセルを表示する
            let cell = tableView.dequeueReusableCell(withIdentifier: "registerBtncell", for: indexPath) as! registerTableViewCell
            cell.selectionStyle = UITableViewCell.SelectionStyle.none
            if NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_BLUE.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_RED.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLUE.rawValue {
                cell.registerBtn.backgroundColor = NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
            }else if NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLACK.rawValue {
                cell.registerBtn.backgroundColor = BLACK
            }else{
                cell.registerBtn.backgroundColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
            }
            tableView.tableFooterView = UIView()
            cell.separatorInset = UIEdgeInsets.init(top: 0, left: myAppFrameSize.width, bottom: 0, right: 0)
            cell.tutorialBtn.setTitle(localText(key:"home_tutorial_label"),for: .normal)
            if musiclibraryExtentFlg {
                cell.tutorialImg.isHidden = true
                cell.tutorialBtn.isHidden = true
            }else{
                cell.tutorialImg.isHidden = false
                cell.tutorialBtn.isHidden = false
            }
            fadeInRanDomAnimesion(view : cell.registerBtn)
            return cell
        }else{
            //musictableview.rowHeight =  CGFloat(CELL_ROW_HEIGT_MIDDLE)
            // テーブルのセルを参照する
            let cell = tableView.dequeueReusableCell(withIdentifier: "MusicLibrary", for: indexPath) as! HomeTableViewCell
            // テーブルにMusicLibraryListのデータを表示する
            let myMusicLibraryData = musicLibraryList[(indexPath as NSIndexPath).row]
            cell.libraryTitleLabel.text = myMusicLibraryData.musicLibraryName
            if myMusicLibraryData.musicLibraryName == MV_LIST_NAME{
                cell.libraryContentsTypeLabel.text = CONTENTS_TYPE_MV
                myViewOKINIIRIAREA.isUserInteractionEnabled = false
                cell.addSubview(myViewOKINIIRIAREA)
                cell.libraryTitleLabel.text = localText(key:"home_okiniiri_title")
                cell.libraryNumLabel.text = ""
            }else{
                cell.libraryContentsTypeLabel.text = CONTENTS_TYPE_MUSIC
                cell.libraryNumLabel.text = String(indexPath.row)
                
            }
            cell.librarySubTitleLabel.text = String(myMusicLibraryData.trackNum)
            
            if indexPath.row == 0 {
                cell.libraryImage.image = UIImage(named: "OKINIIRIICON")
            } else {
                cell.libraryImage.image = UIImage(named: "onpu00")
            }
            if NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_BLUE.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_RED.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLUE.rawValue {
                cell.libraryImage.backgroundColor = NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
            }else if NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLACK.rawValue {
                cell.libraryImage.backgroundColor = BLACK
            }else{
                cell.libraryImage.backgroundColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
            }

            // アイコン設定
            cell.libraryImage.contentMode = .center
            cell.libraryImage.layer.cornerRadius = 5
            
            cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
            // イコライザー設定
            if NowPlayingMusicLibraryData.nowPlayingLibrary == myMusicLibraryData.musicLibraryName && audioPlayer != nil && audioPlayer.isPlaying {
            //if indexPath.row != 0 {
                // イコライザー設定
                //audioPlayer.delegate = self
                let gifData = darkPlayGif(vc : self)
//                let jscript = "var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width'); document.getElementsByTagName('head')[0].appendChild(meta);"
//                let userScript = WKUserScript(source: jscript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
//                let wkUController = WKUserContentController()
//                wkUController.addUserScript(userScript)
//                let wkWebConfig = WKWebViewConfiguration()
//                wkWebConfig.userContentController = wkUController
//                //cell.animationGifWebView = WKWebView(frame: self.view.bounds, configuration: wkWebConfig)
                cell.animationGifWebView.scrollView.isScrollEnabled = false
                cell.animationGifWebView.load(gifData as Data, mimeType: "image/gif", characterEncodingName: "utf-8", baseURL: NSURL() as URL)
                cell.libraryImage.isHidden = true
                cell.animationGifWebView.isHidden = false
            } else {
                cell.animationGifWebView.isHidden = true
                cell.libraryImage.isHidden = false
                fadeInRanDomAnimesion(view : cell.libraryImage)
            }
            
            cell.rightUtilityButtons = self.getRightUtilityButtonsToCell() as [AnyObject]
            // アクションを受け取るために設定
            cell.delegate = self
            tableView.separatorStyle = .singleLine
            return cell
        }
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        // ライブラリ削除処理へ
        if deleteMusicLibrary(deleteMusicLibraryName:self.musicLibraryList[indexPath.row].musicLibraryName){
            self.reloardFromDeleteMusicLibrary(index:indexPath.row)
        }
    }
    
    // tableのcell並び替え時に呼ばれるメソッド
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath){
        if destinationIndexPath.row == 0 {
            musictableview.reloadData()
            return
        }
        if destinationIndexPath.row == musicLibraryList.count {
            
            musictableview.reloadData()
            return
        }
        //移動されたデータを取得する。
        let moveData = musicLibraryList[sourceIndexPath.row]
        print("moveData: \(moveData)")
        
        //元の位置のデータを配列から削除する。
        musicLibraryList.remove(at: sourceIndexPath.row)
        
        //移動先の位置にデータを配列に挿入する。
        musicLibraryList.insert(moveData , at:destinationIndexPath.row)
        print("After moveData insert: \(musicLibraryList)")
        musictableview.reloadData()
    }
    // tableのcellタップ時に呼ばれるメソッド
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath as IndexPath, animated: true)
        
        // チュートリアルのタップは無視
        if musiclibraryExtentFlg == false && indexPath.row == 1{
            return
        }
        if  indexPath.row == musicLibraryList.count{
            return
        }
        
        selectMusicLibraryName = musicLibraryList[indexPath.row].musicLibraryName
        if selectMusicLibraryName == MV_LIST_NAME{
            performSegue(withIdentifier: "toMVPlayList", sender: "")
            return
        }
        selectMusicLibraryTrackNum = musicLibraryList[indexPath.row].trackNum
        selectMusicLibraryImageColorName = musicLibraryList[indexPath.row].iconColorName
        selectMusicLibraryIconName = musicLibraryList[indexPath.row].iconName
        newMusicLibraryCode = indexPath.row
        performSegue(withIdentifier: "toPlayList", sender: "")
    }
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        
        switch indexPath.row { // crash
        case musicLibraryList.count:
            return nil;
            
        case musicLibraryList.count  + 1:
            if musiclibraryExtentFlg == false{
                return nil;
            }
            return indexPath;
            
        default:
            return indexPath;
        }
    }
    
    // tableのButtonを拡張 -右からのスワイプ時のボタンの定義
    func getRightUtilityButtonsToCell()-> NSArray {
        let utilityButtons: NSMutableArray = NSMutableArray()
        utilityButtons.add(addUtilityButtonWithColor(color: UIColor.lightGray, icon:UIImage(named: "rename")!))
        utilityButtons.add(addUtilityButtonWithColor(color: UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.8), icon:UIImage(named: "delete")!))
        return utilityButtons
    }
    // ボタンの追加(なんかObj-CのNSMutableArray拡張ヘッダーが上手く反映できてないので)
    func addUtilityButtonWithColor(color : UIColor, icon : UIImage) -> UIButton {
        let button:UIButton = UIButton(type: UIButton.ButtonType.custom)
        button.backgroundColor = color
        button.setImage(icon, for: .normal)
        return button
    }
    
    // 右からのスワイプ時のボタンのアクション
    func swipeableTableViewCell(_ cell: SWTableViewCell!, didTriggerRightUtilityButtonWith index: Int) {
        let point = musictableview.convert(cell.frame.origin, from: cell.superview)
        if let indexPath = musictableview.indexPathForRow(at: point) {
            print("section: \(indexPath.section) - row: \(indexPath.row)")
            switch index {
            case 0:
                // テキストフィールド付きアラート表示
                let alert = UIAlertController(title: localText(key:"musiclibrary_edit"), message: "", preferredStyle: .alert)
                // OKボタンの設定
                let okAction = UIAlertAction(title: localText(key:"btn_ok"), style: .default, handler: {
                    (action:UIAlertAction!) -> Void in
                    // OKを押した時入力されていたテキストを表示
                    if let textFields = alert.textFields {
                        var newMusicLibralyName = ""
                        // アラートに含まれるすべてのテキストフィールドを調べる
                        for textField in textFields {
                            newMusicLibralyName = textField.text!
                        }
                        if self.musicLibraryList[indexPath.row].musicLibraryName == newMusicLibralyName{
                            // 変わってないから何もしない
                            return
                        }
                        if newMusicLibralyName == "" {
                            showAlertMsgOneOkBtn(title: MUSICLIBRALY_REGIST_ERR_NONNAME_DIALOG_TITLE,messege: MUSICLIBRALY_REGIST_ERR_NONNAME_DIALOG_MESSAGE)
                            return
                        }
                        // 登録されているMusicLibraryNameを確認 → 被りがあったらエラー
                        if checkMusicLibraryNameExistence(checkName:newMusicLibralyName) {
                            showAlertMsgOneOkBtn(title: MUSICLIBRALY_REGIST_ERR_SAMENAME_DIALOG_TITLE,messege: MUSICLIBRALY_REGIST_ERR_SAMENAME_DIALOG_MESSAGE)
                            return
                        }
                        // MusicLibraryModel を更新する
                        let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
                        if changeMusicLibraryName(appdelegate:appDelegate,newName:newMusicLibralyName,
                                                  nowName:self.musicLibraryList[indexPath.row].musicLibraryName) == false {
                            showAlertMsgOneOkBtn(title: MUSICLIBRALY_REGIST_ERR_COREDATA_DIALOG_TITLE,messege: MUSICLIBRALY_REGIST_ERR_COREDATA_DIALOG_MASSAGE)
                            return
                        }
                        self.musicLibraryList[indexPath.row].musicLibraryName = newMusicLibralyName
                    }
                    self.musictableview.reloadData()
                    // アラートを作成
                    showAlertMsgOneOkBtn(title: localText(key:"btn_success"),messege: localText(key:"musiclibrary_editname"))
                })
                alert.addAction(okAction)
                
                // キャンセルボタンの設定
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                alert.addAction(cancelAction)
                
                // テキストフィールドを追加
                alert.addTextField(configurationHandler: {(textField: UITextField!) -> Void in
                    textField.text = self.musicLibraryList[indexPath.row].musicLibraryName
                })
                alert.view.setNeedsLayout() // シミュレータの種類によっては、これがないと警告が発生
                
                // アラートを画面に表示
                self.present(alert, animated: true, completion: nil)
                
            case 1:
                // アラートを作成
                let alert = UIAlertController(
                    title: localText(key:"musiclibrary_delete_conform_title"),
                    message: localText(key:"musiclibrary_delete_conform_body"),
                    preferredStyle: .alert)
                
                // アラートにボタンをつける
                alert.addAction(UIAlertAction(title: MESSAGE_YES, style: .default, handler: { action in
                    if deleteMusicLibrary(deleteMusicLibraryName:self.musicLibraryList[indexPath.row].musicLibraryName){
                        self.reloardFromDeleteMusicLibrary(index:indexPath.row)
                        showToastMsg(messege:LISTMODE_LIVRARY_DELETE,time:2.0, tab: COLOR_THEMA.HOME.rawValue)
                    }
                }))
                
                alert.addAction(UIAlertAction(title: MESSAGE_NO, style: .default, handler: { action in
                    // NOが押されたら何もしない
                    return
                }))
                // アラート表示
                getForegroundViewController().present(alert, animated: true, completion: nil)
                
            default:
                print("other")
            }
        }
    }
    /*******************************************************************
     ライブラリ削除時の処理
     *******************************************************************/
    func reloardFromDeleteMusicLibrary(index:Int){
        self.musicLibraryList.remove(at: index)
        self.musictableview.reloadData()
        if self.musicLibraryList.count == 1 {
            self.musictableview.isEditing = false
            self.musiclibraryExtentFlg = false
            // 編集完了ボタンの無効化
            navigationItem.rightBarButtonItems = [makeQuestionBtn()]
        }
        // 音楽再生中であれば再生を止める TODO 削除されたライブラリ以外は止めなくても良いのでは？
        if audioPlayer == nil {
            return
        }
        if (audioPlayer.isPlaying){
            // 一旦音楽は止める
            audioPlayer.stop()
        }
    }
    /*******************************************************************
     ボタンタップ時処理
     *******************************************************************/
    @IBAction func rewardADBtnTapped(_ sender: Any) {
        removeADAlertApear(vc:self,rewardedAd: rewardedAd)
    }
    // 「音楽ライブラリを作成する」ボタンタップ時
    @IBAction func makeMusicLibraryBtnTapped(_ sender: Any) {
        //tappedAnimation(tappedBtn: sender as! UIButton )
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.1, animations: {
                //縮小の処理
                (sender as! UIButton).transform = CGAffineTransform(scaleX: 3/4, y: 3/4)
            }, completion: { _ in

                CUSTOM_LYBRARY_NAME = ""
                CUSTOM_LYBRARY_FROM_MUSICLIST = false
                self.performSegue(withIdentifier: "toOSAlbumList", sender: "")
            })
            UIView.animate(withDuration: 0.3, animations: {
                //拡大の処理
                (sender as! UIButton).transform = CGAffineTransform(scaleX: 1, y: 1)
            }, completion: { _ in
            })
        }
    }
    
    // tableのcell「Delete」ボタンタップ時
    @IBAction func musicLibraryDeleteModeBtn(_ sender: Any) {
        if musictableview.isEditing == true{
            musictableview.isEditing = false
        }else{
            musictableview.isEditing = true
        }
    }
    // 「編集完了」ボタン押下時
    @objc func editDoneBtnTapped(_ sender: Any) {
        musictableview.isEditing = false
        // 編集完了ボタンの無効化
        navigationItem.rightBarButtonItems = [makeQuestionBtn()]
        let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
        let context:NSManagedObjectContext = appDelegate.managedObjectContext
        let fetchRequest:NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
        let fetchData = try! context.fetch(fetchRequest)
        DispatchQueue.main.async {
            // 並び替え後のデータを保存
            if(!fetchData.isEmpty){
                for i in 0..<self.musicLibraryList.count{
                    for j in 0..<fetchData.count{
                        if fetchData[j].musicLibraryName == self.musicLibraryList[i].musicLibraryName{
                            fetchData[j].indicatoryNum = Int16(i)
                        }
                    }
                }
                do{
                    try context.save()
                }catch{
                    print(error)
                }
            }
        }
    }
    
    // 「＋」ボタン押下時
    @IBAction func musicLibraryRegisterBtnTapped(_ sender: Any) {
        
        CUSTOM_LYBRARY_FROM_MUSICLIST = false
        performSegue(withIdentifier: "toOSAlbumList", sender: "")
    }
    // 「？」ボタン押下時
    @objc func questionBtnTapped(_ sender: Any) {
        // アラートを作成
        let alert = UIAlertController(
            title: localText(key:"home_help_title"),
            message: localText(key:"home_help_body"),
            preferredStyle: .alert)

        // アラートにボタンをつける
        alert.addAction(UIAlertAction(title: localText(key:"home_help_nolook"), style: .cancel))
        alert.addAction(UIAlertAction(title: localText(key:"home_help_look"), style: .default, handler: { action in
            self.musictableview.setContentOffset(CGPoint(x : 0, y : -Int(self.musictableview.contentInset.top)), animated: true)
            self.coachMarksController.start(in: .newWindow(over: self, at: nil))
        }))
        self.present(alert, animated: true, completion: nil)
    }
    // cell長押し時に呼ばれるメソッド
    @objc func cellLongPressed(recognizer: UILongPressGestureRecognizer) {
        // チュートリアルのタップは無視
        if musiclibraryExtentFlg == false {
            return
        }
        if musictableview.isEditing == false{
            musictableview.isEditing = true
            // 編集完了ボタンの有効化
            navigationItem.rightBarButtonItems = [makeEditBtn()]
        }
    }
    
    /*******************************************************************
     広告関連の処理
     *******************************************************************/
    // Reward広告準備完了かのチェック
    func checkRewardAD(){
        if ADApearFlg() {
            navigationItem.leftBarButtonItems = [rewardADAre] // crash
            if rewardedAd!.isReady {
                rewardADBtn.isHidden = false
            }else{
                rewardADBtn.isHidden = true
            }
        }else{
            navigationItem.leftBarButtonItems = []
        }
    }
    /*---------------------
     ADMOB Reward delegate
     --------------------*/
    func rewardedAd(_ rewardedAd: GADRewardedAd, userDidEarn reward: GADAdReward) {
        let now = NSDate()
        let date1 = NSDate(timeInterval: TimeInterval(60 * 60 * Int(truncating: 3)), since: now as Date)
        UserDefaults.standard.set(date1, forKey: "ADdate")
        UserDefaults.standard.synchronize()
        deleteAD()
        self.loadView()
        self.viewDidLoad()
    }
    func rewardedAdDidDismiss(_ rewardedAd: GADRewardedAd) {
      if DEBUG_FLG {
          let _ad = GADRewardedAd(adUnitID: ADMOB_REWARD_TRANS_test)
          _ad.load(GADRequest())
      }else{
          let _ad = GADRewardedAd(adUnitID: ADMOB_REWARD_AD)
          _ad.load(GADRequest())
      }
    }
    func adViewDidFail(toLoad view: AmazonAdView!, withError: AmazonAdError!) -> Void {
        Swift.print("Ad Failed to load. Error code \(withError.errorCode): \(String(describing: withError.errorDescription))")
    }
    func adViewWillExpand(_ view: AmazonAdView!) -> Void {
        Swift.print("Ad will expand")
    }
    func adViewDidCollapse(_ view: AmazonAdView!) -> Void {
        Swift.print("Ad has collapsed")
    }
    
    // FIVE
    func fiveAdDidLoad(_ ad: FADAdInterface!) {
    }
    var fadDelegate:FADDelegate!
    func fiveAdDidReplay(_ ad: FADAdInterface!) {
        print(FADAdInterface.self)
    }
    func fiveAdDidViewThrough(_ ad: FADAdInterface!) {
        print(FADAdInterface.self)
    }
    func fiveAdDidResume(_ ad: FADAdInterface!) {
        print(FADAdInterface.self)
    }
    func fiveAdDidPause(_ ad: FADAdInterface!) {
        print(FADAdInterface.self)
    }
    func fiveAdDidStart(_ ad: FADAdInterface!) {
        print(FADAdInterface.self)
    }
    func fiveAdDidClose(_ ad: FADAdInterface!) {
        print(FADAdInterface.self)
    }
    func fiveAdDidClick(_ ad: FADAdInterface!) {
        print(FADAdInterface.self)
    }
    func fiveAd(_ ad: FADAdInterface!, didFailedToReceiveAdWithError errorCode: FADErrorCode) {
        print(errorCode)
    }
    // 必ず実装してください。
    // AmazonAdViewDelegate APVAdManagerDelegate で使う
    func viewControllerForPresentingModalView() -> UIViewController! {
        return self
    }
    // 動画の再生準備完了通知です。
    func onReady(toPlayAd ad: APVAdManager!, for nativeAd: APVNativeAd!) {
        myADView.backgroundColor = UIColor.lightGray
        myADView.addSubview(aPVAd)
        ad.showAd(for: aPVAd)

    }
    
    /*******************************************************************
     チュートリアルの処理
     *******************************************************************/
    func numberOfCoachMarks(for coachMarksController: CoachMarksController) -> Int {
        return 5
    }
    func coachMarksController(_ coachMarksController: CoachMarksController,
                              coachMarkAt index: Int) -> CoachMark {
        switch index {
        case 99:
            return coachMarksController.helper.makeCoachMark(for: myADView)
        case 0:
            return coachMarksController.helper.makeCoachMark(for: myViewOKINIIRIAREA)
        case 1:
            return coachMarksController.helper.makeCoachMark(for: myViewtabViewSearchItem)
        case 2:
            return coachMarksController.helper.makeCoachMark(for: myViewtabViewRankingItem)
        case 3:
            return coachMarksController.helper.makeCoachMark(for: corchMusicarea)
        case 4:
            return coachMarksController.helper.makeCoachMark(for: myViewtabViewSettingItem)
        default:
            return coachMarksController.helper.makeCoachMark(for: corchMusicarea)

        }
    }
    
    func coachMarksController(_ coachMarksController: CoachMarksController, coachMarkViewsAt index: Int, madeFrom coachMark: CoachMark) -> (bodyView: (UIView & CoachMarkBodyView), arrowView: (UIView & CoachMarkArrowView)?) {

        let coachViews = coachMarksController.helper.makeDefaultCoachViews(withArrow: true, arrowOrientation: coachMark.arrowOrientation)

        switch index {
        case 99:
            coachViews.bodyView.hintLabel.text = localText(key:"home_help_1")
            coachViews.bodyView.nextLabel.text = localText(key:"btn_ok")
        case 0:
            coachViews.bodyView.hintLabel.text = localText(key:"home_help_2")
            coachViews.bodyView.nextLabel.text = localText(key:"btn_ok")
        case 1:
            coachViews.bodyView.hintLabel.text = localText(key:"home_help_3")
            coachViews.bodyView.nextLabel.text = localText(key:"btn_ok")
        case 2:
            coachViews.bodyView.hintLabel.text = localText(key:"home_help_4")
            coachViews.bodyView.nextLabel.text = localText(key:"btn_ok")
        case 3:
            coachViews.bodyView.hintLabel.text = localText(key:"home_help_5")
            coachViews.bodyView.nextLabel.text = localText(key:"btn_ok")
        case 98:
            coachViews.bodyView.hintLabel.text = localText(key:"home_help_6")
            coachViews.bodyView.nextLabel.text = localText(key:"btn_ok")
        case 97:
            coachViews.bodyView.hintLabel.text = localText(key:"home_help_7")
            coachViews.bodyView.nextLabel.text = localText(key:"btn_ok")
        case 4:
            coachViews.bodyView.hintLabel.text = localText(key:"home_help_8")
            coachViews.bodyView.nextLabel.text = localText(key:"btn_ok")
        default:
            coachViews.bodyView.hintLabel.text = localText(key:"home_help_9")
            coachViews.bodyView.nextLabel.text = localText(key:"btn_ok")
        }
    
        coachViews.bodyView.nextLabel.textColor = UIColor(red: 0.8, green: 0.0, blue: 0.4, alpha: 1.0)
        
        return (bodyView: coachViews.bodyView, arrowView: coachViews.arrowView)
    }
    
    /*******************************************************************
     画面遷移時処理
     *******************************************************************/
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //Track 一覧画面へ
        if segue.identifier == "toPlayList" {
            // MusicPlayListViewControllerをインスタンス化
            let nextVc = segue.destination as! MusicPlayListViewController
            nextVc.musicLibraryName = selectMusicLibraryName
            nextVc.iconColorName = selectMusicLibraryImageColorName
            nextVc.newMusicLibraryCode = newMusicLibraryCode
            nextVc.iconName = selectMusicLibraryIconName
            returnEditFlg = true
            // コマンドセンター解除
            mMusicController.commandAllRemove()
            // AVAudio Session
            let center = NotificationCenter.default
            center.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
            center.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
        }
    }
    
    // 再生終了時の呼び出しメソッド
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // 最後の曲再生中かつ、リピートフラグが立っていなければ終了
        if NowPlayingMusicLibraryData.nowPlaying == selectMusicLibraryTrackNum - 1 && SHUFFLE_FLG == false && repeatState == REPEAT_STATE_NONE{
            if repeatState != REPEAT_STATE_ALL {
                newSelectPlayNum = 0
                // プレイヤー初期化
                if audioPlayer != nil {
                    audioPlayer.stop()
                }
                musictableview.reloadData()
                return
            }
        }
        desideNextPlayMusic(next: true)
    }
    // 次に再生する曲をセットする
    func desideNextPlayMusic(next : Bool) {
        if NowPlayingMusicLibraryData.musicLibraryCode != displayMusicLibraryData.musicLibraryCode {
            NowPlayingMusicLibraryData = NowPlayingData()
            NowPlayingMusicLibraryData = displayMusicLibraryData
            NowPlayingMusicLibraryData.nowPlaying = 0
            //NowPlayingMusicLibraryData.nowPlayingLibrary = self.musicLibraryName
        }
        
        switch next {
        case NEXT:
            if NEXT_TAP_FLG == false && repeatState == REPEAT_STATE_ONE {
                // 再生する曲は変更しない
                break
            }
            if NowPlayingMusicLibraryData.nowPlaying == NowPlayingMusicLibraryData.trackData.count - 1 {
                // 最後の曲を再生中だったら、最初の曲へ
                NowPlayingMusicLibraryData.nowPlaying = 0
            }else{
                // その他は、一つ次の曲へ
                NowPlayingMusicLibraryData.nowPlaying = NowPlayingMusicLibraryData.nowPlaying + 1
            }
            NEXT_TAP_FLG = false
            
        case PREV:
            if NowPlayingMusicLibraryData.nowPlaying <= 0 {
                // 最初の曲を再生中だったら、最後の曲へ
                NowPlayingMusicLibraryData.nowPlaying = NowPlayingMusicLibraryData.trackData.count - 1
            }else{
                NowPlayingMusicLibraryData.nowPlaying = NowPlayingMusicLibraryData.nowPlaying - 1
            }
        default: break
            
        }
        if SHUFFLE_FLG {
            playMusicWrapper(playData: NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying])
            
        }else {
            playMusicWrapper(playData: NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying])
            
        }
    }
    //  音楽再生のためのラッパー関数
    func playMusicWrapper(playData: TrackData){
        if mMusicController.playMusic(playData: playData,vc: self) == CODE_SUCCESS {
            NowPlayingMusicLibraryData.musicLibraryCode = newMusicLibraryCode
            audioPlayer.delegate = nil
            audioPlayer.delegate = self
            audioPlayer.volume = volume
            let speed = speedList[speedRow] * 10
            audioPlayer.rate = Float(round(speed) / 10)
        }else{
            // アラートを作成
            showAlertMsgOneOkBtn(title: ERR_DIALOGUE_TITLE_MUSIC_DATA_NONE,messege: ERR_DIALOGUE_MESSAGE_MUSIC_DATA_NONE + "¥n" + mMusicController.playMusic(playData: playData,vc: self))
        }
        musictableview.reloadData()
    }
    
    // 次の曲再生
    @objc func nextMusicPlay(){
        desideNextPlayMusic(next: true)
    }
    // 前の曲再生
    @objc func prevMusicPlay(){
        desideNextPlayMusic(next: false)
    }
    @objc func play (){
        if audioPlayer == nil{
            return
        }
        audioPlayer.play()
        musictableview.reloadData()
    }
    @objc func stop (){
        if audioPlayer == nil{
            return
        }
        audioPlayer.stop()
    }
    /*******************************************************************
     割り込み時の音声制御
     *******************************************************************/
    /// Interruption : 電話による割り込み
    @objc func handleInterruption(_ notification: NSNotification) {
        
        let interruptionTypeObj = notification.userInfo![AVAudioSessionInterruptionTypeKey] as! NSNumber
        if let interruptionType = AVAudioSession.InterruptionType(rawValue:
            interruptionTypeObj.uintValue) {
            
            switch interruptionType {
            case .began:
                // interruptionが開始した時(電話がかかってきたなど)
                if audioPlayer == nil {
                    return
                }else{
                    if playedFlg {
                        playedFlg = false
                        //audioPlayer.play()
                    }
                }
                break
            case .ended:
                // interruptionが終了した時の処理
                if(audioPlayer == nil){
                    return
                }else{
                    playedFlg = true
                    audioPlayer.stop()
                }
                break
                
            }
            //テーブルの再読み込み
            musictableview.reloadData()
        }
        
    }
    // Audio Session Route Change : ルートが変化した(ヘッドセットが抜き差しされた)
    @objc func audioSessionRouteChanged(_ notification: Notification) {
        let reasonObj = (notification as NSNotification).userInfo![AVAudioSessionRouteChangeReasonKey] as! NSNumber
        if let reason = AVAudioSession.RouteChangeReason(rawValue: reasonObj.uintValue) {
            switch reason {
            case .newDeviceAvailable:
                // 新たなデバイスのルートが使用可能になった
                if audioPlayer == nil {
                    return
                }else{
                    if playedFlg {
                        playedFlg = false
                        audioPlayer.play()
                    }
                }
                break
            case .oldDeviceUnavailable:
                playedFlg = false
                if(audioPlayer == nil){
                    return
                }else{
                    if audioPlayer.isPlaying {
                        playedFlg = true
                        audioPlayer.stop()
                    }
                }
                break
            default:
                break
            }
            //テーブルの再読み込み
            DispatchQueue.main.async {
                self.musictableview.reloadData()
            }
        }
    }
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        let center = NotificationCenter.default
        
        // AVAudio Session
        center.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        center.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
        
    }
}




