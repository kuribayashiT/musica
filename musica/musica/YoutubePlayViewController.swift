//
//  YoutubePlayViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2017/10/01.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import AdSupport
import CoreData
import MediaPlayer
import AVFoundation
import GoogleMobileAds
import Reachability
import YoutubePlayer_in_WKWebView
import Firebase
import XCDYouTubeKit
import AVKit

class YoutubePlayViewController: UIViewController,UIPickerViewDelegate, UIPickerViewDataSource ,FullScreenContentDelegate ,UITabBarDelegate,AVPlayerViewControllerDelegate{
    
    let volumeControl = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 120, height: 120))

    @IBOutlet weak var kakeruLbl: UILabel!
    @IBOutlet weak var youtubeUI: UIView!
    //var youtubeWK = WKWebView()
    @IBOutlet weak var baseWk: UIView!
    var playVideoUrl = ""
    var mplayVideoUrl = ""
    var oldUrl = ""
    var NowVideo = ""
    @IBOutlet weak var quoSwitch: UISegmentedControl!
    var quoFlg = false
    @IBOutlet weak var waitView: UIVisualEffectView!
    var nowViewDeirectionPort = true
    @IBOutlet weak var repeatBtn: UIButton!
    @IBOutlet weak var youtubeVideoView: WKYTPlayerView!
    @IBOutlet weak var hidePickerView: UIVisualEffectView!
    @IBOutlet weak var speedPicker: UIPickerView!
    @IBOutlet weak var susumuBtn: UIButton!
    @IBOutlet weak var errorView: UIView!
    @IBOutlet weak var shuffleBtn: UIButton!
    @IBOutlet weak var modoruBtn: UIButton!
    @IBOutlet weak var youtubeAVKitView: UIView!
    var AVPlayerCheckTimer = Timer()
    var MV_PLAY_flg = false
    var _prevPrevPrevTime : CMTime = CMTime.zero
    var _prevPrevTime : CMTime = CMTime.zero
    var _prevTime : CMTime = CMTime.zero
    var YOUTUBE_ONERROR_FLG = false
    // AD
    var interstitial: InterstitialAd?
    var youtubeVideoIdList : [String] = []
    var shuffleVideoIdList : [String] = []
    var youtubePlaylistVideoIDs = ""
    var selectedVideoNum = 0
    var longVideoApperADFlg = false
    var FROM_AD_FLG = false
    
    // オフライン検知
    let reachability = try! Reachability()
    // timer
    var nowVideo: XCDYouTubeVideo = XCDYouTubeVideo()
    
    // DEBUG
    var debug_state = ""
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        susumuBtn.tintColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        modoruBtn.tintColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let volume = MPVolumeView(frame: .zero)
        volume.setVolumeThumbImage(UIImage(), for: UIControl.State())
        volume.isUserInteractionEnabled = false
        volumeControl.alpha = 0.0001
        volume.showsRouteButton = false
        self.view.addSubview(volumeControl);

        // delegate
        youtubeVideoView.delegate = self
        youtubeVideoView.isHidden = true
        hidePickerView.isHidden = false
        kakeruLbl.isHidden = false
        repeatBtn.isHidden = false
        speedPicker.delegate = self
        speedPicker.dataSource = self
        
        let disableCalloutScriptString = "document.documentElement.style.webkitTouchCallout='none';"
        let disableCalloutScript = WKUserScript(source: disableCalloutScriptString, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        let controller = WKUserContentController()
        controller.addUserScript(disableCalloutScript)
        let viewConfiguration = WKWebViewConfiguration()
        viewConfiguration.userContentController = controller //上記の操作禁止を反映
//        youtubeWK = WKWebView(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.width * 11/16), configuration: viewConfiguration)
//
//
//        youtubeWK.navigationDelegate = self
//        youtubeWK.uiDelegate = self
//        youtubeWK.allowsBackForwardNavigationGestures = true
//
//        youtubeWK.scrollView.bounces = true
//        youtubeWK.addObserver(self, forKeyPath: "URL", options: .new, context: nil)
//        youtubeWK.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil)
//        baseWk.addSubview(youtubeWK)
        // はじめに表示する項目を指定
        speedPicker.selectRow(mvSpeedRow, inComponent: 0, animated: true)

        //youtubeWK.configuration = viewConfiguration
        modoruBtn.setImage(playBackLBtnImage, for: .normal)
        modoruBtn.tintColor = darkModeIconBlackUIcolor()
        susumuBtn.setImage(playNextLBtnImage, for: .normal)
        susumuBtn.tintColor = darkModeIconBlackUIcolor()
        let manager = ASIdentifierManager.shared()
        if manager.isAdvertisingTrackingEnabled { // 広告トラッキングを許可しているのか？
            let idfaString = manager.advertisingIdentifier.uuidString
            print(idfaString)
            if idfaString == "1E79435D-5FF2-489C-9C9C-FA3EDA0254CA" {
                quoSwitch.isHidden = false
            }else{
                quoSwitch.isHidden = true
            }
        }else{
            quoSwitch.isHidden = true
        }
        NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidJumped), name: .AVPlayerItemTimeJumped, object: nil)
        youtubeUI.isHidden = true
    }
    /*******************************************************************
     画面描画時の処理
     *******************************************************************/
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // navigationbarの色設定
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
        
        // Music Player は停止する
        if(audioPlayer != nil){
            if audioPlayer.isPlaying{
                audioPlayer.stop()
            }
        }
        selectMusicView.isHidden = true
        NotificationCenter.default.addObserver(self, selector: #selector(self.reachabilityChanged),name: ReachabilityChangedNotification,object: reachability)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onOrientationChange),name: UIDevice.orientationDidChangeNotification,object: nil)
        
        if selectedVideoNum == -1 {
            self.navigationController?.popViewController(animated: true)
            return
        }
        if quoSwitch.selectedSegmentIndex == 0 {
            quoFlg = true
        }else{
            quoFlg = false
        }
        // オフラインチェック
        checkOffline()
        // 広告の準備
        loadInterstitial()
        // 設定状態反映
        switch repeatMVState {
        case REPEAT_STATE_NONE:
            repeatBtn.setImage(UIImage(named: "repeat")?.withRenderingMode(.alwaysTemplate), for: .normal)
            repeatBtn.tintColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.5)
        case REPEAT_STATE_ALL:
            repeatBtn.setImage(UIImage(named: "repeat")?.withRenderingMode(.alwaysTemplate), for: .normal)
            repeatBtn.tintColor = UIColor(red: 0, green: 122 / 255, blue: 1,alpha: 1)
        case REPEAT_STATE_ONE:
            repeatBtn.setImage(UIImage(named: "repeat1")?.withRenderingMode(.alwaysTemplate), for: .normal)
            repeatBtn.tintColor = UIColor(red: 0, green: 122 / 255, blue: 1,alpha: 1)
        default:
            repeatBtn.setImage(UIImage(named: "repeat")?.withRenderingMode(.alwaysTemplate), for: .normal)
            repeatBtn.tintColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.5)
        }
        if SHUFFLE_MV_FLG {
            shuffleBtn.setImage(UIImage(named: "shuffle")?.withRenderingMode(.alwaysTemplate), for: .normal)
            shuffleBtn.tintColor = UIColor(red: 0, green: 122 / 255, blue: 1,alpha: 1)
        }else{
            shuffleBtn.setImage(UIImage(named: "shuffle")?.withRenderingMode(.alwaysTemplate), for: .normal)
            shuffleBtn.tintColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.5)
        }
        
        if !FROM_AD_FLG {
            // お気に入り情報を初期化
            self.youtubeVideoIdList = []
            let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
            let context:NSManagedObjectContext = appDelegate.managedObjectContext
            let fetchRequest:NSFetchRequest<MVModel> = MVModel.fetchRequest()
            let predicate = NSPredicate(format:"%K = %@","musicLibraryName",MV_LIST_NAME)
            fetchRequest.predicate = predicate
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "indicatoryNum", ascending: true)]
            let fetchData = try! context.fetch(fetchRequest)
            if(!fetchData.isEmpty){
                print(fetchData)
                for i in 0..<fetchData.count{
                    self.youtubeVideoIdList.append(fetchData[i].videoID!)
                }
            }
            if AVPlayerViewControllerManager.shared.controller.player != nil{
                AVPlayerViewControllerManager.shared.controller.player?.rate = nowRate
            }
            // playList作成
            shuffleVideoIdList = youtubeVideoIdList.oriShuffled
            FROM_AD_FLG = false
//            if YOUTUBE_PLAYER_FLG {
//                self.hidePickerView.isHidden = true
//                youtubeAVKitView.isHidden = false
//                if NOW_PLAYING_MV == -1 {
//                    makePlaylist(startListNum: selectedVideoNum)
//                }else{
//                    if SHUFFLE_MV_FLG {
//                        if youtubeVideoIdList[selectedVideoNum] != _videpID{
//                            selectedVideoNum = getIndexInShuffle(id:youtubeVideoIdList[selectedVideoNum])
//                            makePlaylist(startListNum: selectedVideoNum)
//                            return
//                        }
//                    }else{
//                        if youtubeVideoIdList[selectedVideoNum] != _videpID{
//                            makePlaylist(startListNum: selectedVideoNum)
//                            return
//                        }
//                    }
//                    if PlayerViewControllerAddFlg {
//                        self.waitView.isHidden = true
//                        AVPlayerViewControllerManager.shared.controller.view.frame = self.youtubeAVKitView.bounds
//                        self.addChild(AVPlayerViewControllerManager.shared.controller)
//                        self.youtubeAVKitView.addSubview(AVPlayerViewControllerManager.shared.controller.view)
//                    }
//                }
//            }else{
                youtubeAVKitView.isHidden = true
                makePlaylist(startListNum: selectedVideoNum)
            
        }
        else{
            if AVPlayerViewControllerManager.shared.controller.player != nil{
                if MV_PLAY_flg {
                    AVPlayerViewControllerManager.shared.controller.player?.play()
                }
            }
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    // Index Search
    func getIndexInShuffle(id:String) -> Int{
        var Index = 0
        for _ID in shuffleVideoIdList {
            if _ID == id {
                return Index
            }
            Index = Index + 1
        }
        return 0
    }
    // playlistを作成
    func makePlaylist(startListNum:Int){
        youtubePlaylistVideoIDs = ""
//        if YOUTUBE_PLAYER_FLG {
//            waitView.isHidden = false
//            if AVPlayerViewControllerManager.shared.controller.player != nil {
//                AVPlayerViewControllerManager.shared.controller.player?.pause()
//            }
//            // selectedVideoNumとNOW_PLAYING_MVを同期
//            NOW_PLAYING_MV = startListNum
//            _videpID = youtubeVideoIdList[NOW_PLAYING_MV]
//            if SHUFFLE_MV_FLG {
//                _videpID = shuffleVideoIdList[NOW_PLAYING_MV]
//            }
//            PLAY_MV_NUM_IN_PLAYLIST = PLAY_MV_NUM_IN_PLAYLIST + 1
//            selectedVideoNum = NOW_PLAYING_MV
//            XCDYouTubeClient.default().getVideoWithIdentifier(_videpID) { (video, error) in
//                self.waitView.isHidden = true
//                guard error == nil else {
//                    Utilities.shared.displayError(error! as NSError, originViewController: self)
//                    self.waitView.isHidden = true
//                    return
//                }
//                AVPlayerViewControllerManager.shared.lowQualityMode = self.quoFlg
//                AVPlayerViewControllerManager.shared.video = video
//                if PlayerViewControllerAddFlg == false {
//                    PlayerViewControllerAddFlg = true
//                }
//                AVPlayerViewControllerManager.shared.controller.view.frame = self.youtubeAVKitView.bounds
//                self.addChild(AVPlayerViewControllerManager.shared.controller)
//                self.youtubeAVKitView.addSubview(AVPlayerViewControllerManager.shared.controller.view)
//                AVPlayerViewControllerManager.shared.controller.didMove(toParent: self)
//                AVPlayerViewControllerManager.shared.controller.player?.play()
//                AVPlayerViewControllerManager.shared.controller.player?.rate = 1.0
//                self.AVPlayerCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true, block: { (timer) in
//                    self.checkNowPlay()
//                })
//            }
//        }else{
        // 選択されたIDを起点にリストを作成
        var regIndex = 0
        for i in 0..<youtubeVideoIdList.count{
            if startListNum + i > youtubeVideoIdList.count-1{
                regIndex = i + startListNum - youtubeVideoIdList.count
            }else{
                regIndex = startListNum + i
            }
//            if regIndex == startListNum{
//                continue
//            }
            if youtubePlaylistVideoIDs == "" {
                youtubePlaylistVideoIDs = youtubeVideoIdList[regIndex]
            }else{
                youtubePlaylistVideoIDs = youtubePlaylistVideoIDs + "," + youtubeVideoIdList[regIndex]
            }
        }
        print(youtubeVideoIdList)
        print("------uRyAS_F3C20")
        print(youtubePlaylistVideoIDs)
        // playlistを設定
        let playerVars = [
                "fs": "0",// 1
                "origin": "https://youtube.com",
                "playsinline": "1",
                "controls": "2",
                "showinfo": "1",
                "rel": "0",
                "loop": "0",
                "playlist" : youtubePlaylistVideoIDs,
                "modestbranding": "1" ,
                "iv_load_policy": "3",
                "enablejsapi": "1"
        ]
        if youtubeVideoView.load(withVideoId: self.youtubeVideoIdList[startListNum], playerVars: playerVars) {
            //setTimeOut()
        }
        checkOffline()
        // repeat 設定を参照
        switch repeatMVState {
        case REPEAT_STATE_NONE:
            youtubeVideoView.setLoop(false)
        case REPEAT_STATE_ALL:
            youtubeVideoView.setLoop(true)
        case REPEAT_STATE_ONE:
            youtubeVideoView.setLoop(true)
        default:
            break
        }
        
    }
    /*******************************************************************
     スピードピッカー
     *******************************************************************/
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        // 表示する列数
        return 1
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        // アイテム表示個数を返す
        return mvSpeedList.count
    }
//    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
//        // 表示する文字列を返す
//        return String(mvSpeedList[row])
//    }
    // 選択時の処理
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if YOUTUBE_PLAYER_FLG {
            //if nowRate == Float(mvSpeedList[row]){return}
            nowRate = Float(mvSpeedList[row])
            mvSpeedRow = row
            if AVPlayerViewControllerManager.shared.controller.player?.rate != 0 {
                AVPlayerViewControllerManager.shared.controller.player?.rate = nowRate
            }
            self.rateMsgAlert(type:YoutubeRateMsgType.SUCCESS.rawValue,speed: nowRate)
        }else{
            if nowRate == mvSpeedList[row]{return}
            setRate(setRate:mvSpeedList[row])
        }
    }
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int,
            forComponent component: Int, reusing view: UIView?) -> UIView
    {
        let label = (view as? UILabel) ?? UILabel()
        label.text = String(mvSpeedList[row])
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        return label
    }
    /*******************************************************************
     ビデオクオリティースイッチャー
     *******************************************************************/
    @IBAction func quoSwitch(_ sender: Any) {
        if quoSwitch.selectedSegmentIndex == 0 {
            quoFlg = true
        }else{
            quoFlg = false
        }
    }
    /*******************************************************************
     タイムアウト処理
     *******************************************************************/
    // 再生中かチェック
//    func checkNowPlay(){
//        if topViewController(controller: getForegroundViewController()) is YoutubePlayViewController || NSStringFromClass(type(of: topViewController(controller: getForegroundViewController())!)) == "AVFullScreenViewController" || topViewController(controller: getForegroundViewController()) is PlayMVViewController {
//            if AVPlayerViewControllerManager.shared.controller.player != nil {
//                if AVPlayerViewControllerManager.shared.controller.player?.error == nil {
//                    if AVPlayerViewControllerManager.shared.controller.player!.rate > Float(0) {
//                        AVPlayerViewControllerManager.shared.controller.player?.rate = nowRate
//                        _prevPrevPrevTime = CMTime.zero
//                        _prevPrevTime = CMTime.zero
//                        _prevTime = CMTime.zero
//                    }
//                    // 音出てるかチェック
//                    if AVPlayerViewControllerManager.shared.controller.player!.rate == 0.0{
//                        let _nowTime = AVPlayerViewControllerManager.shared.controller.player!.currentTime()
//                        if _prevPrevPrevTime == _prevPrevTime{
//                            // 停止中
//                        }else{
//                            if _prevPrevTime == _prevTime {
//                                // 停止中
//                            }else{
//                                if _prevTime == _nowTime {
//                                    // 停止中と判断
//                                }else{
//                                    // 3回連続でシークバーが進んでたら再生中かつ音が出てない
//                                    AVPlayerViewControllerManager.shared.controller.player?.rate = nowRate
//                                    _prevPrevPrevTime = CMTime.zero
//                                    _prevPrevTime = CMTime.zero
//                                    _prevTime = CMTime.zero
//                                }
//                            }
//                        }
//                        _prevPrevPrevTime = _prevPrevTime
//                        _prevPrevTime = _prevTime
//                        _prevTime = _nowTime
//                    }
//                }
//            }
//        }else{
//            if AVPlayerViewControllerManager.shared.controller.player != nil {
//                AVPlayerViewControllerManager.shared.controller.player?.pause()
//                FROM_AD_FLG = true
//            }
//        }
//    }
//    func setTimeOut(){
//        if MVLoadTimer != nil{
//            // timerが起動中なら一旦破棄する
//            MVLoadTimer.invalidate()
//        }
//        MVLoadTimer = Timer.scheduledTimer(
//            timeInterval: 7,
//            target: self,
//            selector: #selector(self.MVtimeOutErr),
//            userInfo: nil,
//            repeats: false)
//
//    }
//    @objc func MVtimeOutErr(){
//        showAlertMsgOneOkBtn(title: MV_PLAY_FAILURE_TITLE,messege: MV_PLAY_FAILURE_NETWORK)
//        if MVLoadTimer != nil{
//            // timerが起動中なら一旦破棄する
//            MVLoadTimer.invalidate()
//        }
//        youtubeVideoView.stopVideo()
//    }
    /*******************************************************************
     再生終了時処理
     *******************************************************************/
    var tapFlg = false
    @objc func playerDidJumped(){
        print("Jump")
//        print(AVPlayerViewControllerManager.shared.controller.player?.rate)
//        if AVPlayerViewControllerManager.shared.controller.player?.rate == 0 {
//            AVPlayerViewControllerManager.shared.controller.player?.rate = nowRate
//        }
    }
    @objc func playerDidFinishPlaying(){
        tapFlg = false
        dicideNextMV()
    }
    func dicideNextMV(){
        if repeatMVState == REPEAT_STATE_ONE && tapFlg == false{
            if AVPlayerViewControllerManager.shared.controller.player != nil {
                AVPlayerViewControllerManager.shared.controller.player?.currentItem?.seek(to: CMTime.zero, completionHandler: nil)
                AVPlayerViewControllerManager.shared.controller.player?.play()
            }
        }else{
            self.waitView.isHidden = false
            let nextPlayMV = NOW_PLAYING_MV + 1
            if nextPlayMV >= youtubeVideoIdList.count {
                if repeatMVState == REPEAT_STATE_ALL {
                    PLAY_MV_NUM_IN_PLAYLIST = 0
                    makePlaylist(startListNum:0)
                }
                if tapFlg {
                    PLAY_MV_NUM_IN_PLAYLIST = 0
                    makePlaylist(startListNum:0)
                }
                if PLAY_MV_NUM_IN_PLAYLIST >= youtubeVideoIdList.count {
                    self.waitView.isHidden = true
                }
                if AD_DISPLAY_YOUTUBE_CONTENTS != false{
                    if let interstitial = interstitial, nowViewDeirectionPort {
                        youtubeVideoView.pauseVideo()
                        FROM_AD_FLG = true
                        interstitial.present(from: self)
                    }
                }
            }else{
                makePlaylist(startListNum:nextPlayMV)
            }
            tapFlg = false
        }
    }
    func dicidePrevMV(){
        self.waitView.isHidden = false
        let prevPlayMV = NOW_PLAYING_MV - 1
        if prevPlayMV < 0 {
            makePlaylist(startListNum:youtubeVideoIdList.count - 1)
        }else{
            makePlaylist(startListNum:prevPlayMV)
        }
    }
    /*******************************************************************
     ボタンタップ時処理
     *******************************************************************/
    @IBAction func nextTapped(_ sender: Any) {
         nextVideoPlay()
    }
    func nextVideoPlay(){
        //self.waitView.isHidden = false
//        if self.baseWk.isDescendant(of: self.youtubeWK){
//            self.youtubeWK.removeFromSuperview()
//        }
        youtubeUI.isHidden = true
        speedPicker.isHidden = false
        kakeruLbl.isHidden = false

        if YOUTUBE_PLAYER_FLG {
            // 次の曲に行く時には一旦止める
            if AVPlayerViewControllerManager.shared.controller.player != nil {
                AVPlayerViewControllerManager.shared.controller.player?.pause()
            }
            tapFlg = true
            dicideNextMV()
        }else{
            // オフラインチェック
            checkOffline()
            //setTimeOut()
        }
        UIView.animate(withDuration: 0.1, animations: {
            //拡大縮小の処理
            self.susumuBtn.transform = CGAffineTransform(scaleX: 1/2, y: 1/2)
        })
        if youtubeVideoView.isHidden {
            self.youtubeUI.isHidden = true
            self.youtubeVideoView.isHidden = false
            self.kakeruLbl.isHidden = false
            self.speedPicker.isHidden = false
            youtubeVideoView.nextVideo()
        }else{
            youtubeVideoView.nextVideo()
        }
        UIView.animate(withDuration: 0.3, animations: {
            //拡大縮小の処理
            self.susumuBtn.transform = CGAffineTransform(scaleX: 1, y: 1)
        })
    }
    
    @IBAction func prevTapped(_ sender: Any) {
        prevVideoPlay()
    }
    func prevVideoPlay(){
        self.waitView.isHidden = false
//        if self.baseWk.isDescendant(of: self.youtubeWK){
//            self.youtubeWK.removeFromSuperview()
//        }
        youtubeUI.isHidden = true
        speedPicker.isHidden = false
        kakeruLbl.isHidden = false

        // 次の曲に行く時には一旦止める
        if AVPlayerViewControllerManager.shared.controller.player != nil {
            AVPlayerViewControllerManager.shared.controller.player?.pause()
        }
        if YOUTUBE_PLAYER_FLG {
            dicidePrevMV()
        }else{
            // オフラインチェック
            checkOffline()
            //setTimeOut()
        }
        UIView.animate(withDuration: 0.1, animations: {
            //拡大縮小の処理
            self.modoruBtn.transform = CGAffineTransform(scaleX: 1/2, y: 1/2)
        })
        
        if youtubeVideoView.isHidden {
            self.youtubeUI.isHidden = true
            self.youtubeVideoView.isHidden = false
            self.kakeruLbl.isHidden = false
            self.speedPicker.isHidden = false
            youtubeVideoView.playVideo()
            youtubeVideoView.previousVideo()
            youtubeVideoView.previousVideo()
            youtubeVideoView.playVideo()
            self.youtubeVideoView.isHidden = false
        }else{
            youtubeVideoView.previousVideo()
        }
        UIView.animate(withDuration: 0.3, animations: {
            //拡大縮小の処理
            self.modoruBtn.transform = CGAffineTransform(scaleX: 1, y: 1)
        })
    }
    
    @IBAction func shuffleBtnTapped(_ sender: Any) {
        if SHUFFLE_MV_FLG {
            SHUFFLE_MV_FLG = false
            shuffleBtn.setImage(UIImage(named: "shuffle")?.withRenderingMode(.alwaysTemplate), for: .normal)
            shuffleBtn.tintColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.5)
        }else{
            SHUFFLE_MV_FLG = true
            shuffleBtn.setImage(UIImage(named: "shuffle")?.withRenderingMode(.alwaysTemplate), for: .normal)
            shuffleBtn.tintColor = UIColor(red: 0, green: 122 / 255, blue: 1,alpha: 1)
        }
        if YOUTUBE_PLAYER_FLG {
            // 特にやることない？
        }else{
            youtubeVideoView.setShuffle(SHUFFLE_MV_FLG)
        }
    }
    @IBAction func repeatBtnTapped(_ sender: Any) {
        switch repeatMVState {
        case REPEAT_STATE_NONE:
            youtubeVideoView.setLoop(true)
            repeatMVState = REPEAT_STATE_ALL
            repeatBtn.setImage(UIImage(named: "repeat")?.withRenderingMode(.alwaysTemplate), for: .normal)
            repeatBtn.tintColor = UIColor(red: 0, green: 122 / 255, blue: 1,alpha: 1)
        case REPEAT_STATE_ALL:
            youtubeVideoView.setLoop(true)
            repeatMVState = REPEAT_STATE_ONE
            repeatBtn.setImage(UIImage(named: "repeat1")?.withRenderingMode(.alwaysTemplate), for: .normal)
            repeatBtn.tintColor = UIColor(red: 0, green: 122 / 255, blue: 1,alpha: 1)
        case REPEAT_STATE_ONE:
            youtubeVideoView.setLoop(false)
            repeatMVState = REPEAT_STATE_NONE
            repeatBtn.setImage(UIImage(named: "repeat")?.withRenderingMode(.alwaysTemplate), for: .normal)
            repeatBtn.tintColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.5)
        default:
            repeatMVState = REPEAT_STATE_NONE
            repeatBtn.setImage(UIImage(named: "repeat")?.withRenderingMode(.alwaysTemplate), for: .normal)
            repeatBtn.tintColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.5)
        }
    }
    @IBAction func reloadBtnTapped(_ sender: Any) {
        checkOffline()
    }
    
    /*******************************************************************
     非同期で動くYoutube IF Rate処理
     *******************************************************************/
    // get playlist 非同期→同期処理へ
    func getPlaylistDispatch(exifCompletionHandler: @escaping (_ playlist: NSArray) -> Void) -> Void{
        self.youtubeVideoView.getPlaylist({ playlist, error in
            if error == nil {
                if playlist == nil{
                    exifCompletionHandler([])
                }else{
                    exifCompletionHandler(playlist! as NSArray)
                }
            }else{
                exifCompletionHandler([])
            }
        })
    }
    // get playlist index非同期→同期処理へ
    func getPlaylistIndexDispatch(exifCompletionHandler: @escaping (_ playlistIndex: Int) -> Void) -> Void{
        self.youtubeVideoView.getPlaylistIndex({ playlistIndex, error in
            if error == nil {
                exifCompletionHandler(Int(playlistIndex))
            }else{
                exifCompletionHandler(-1)
            }
        })
    }
    // Rate変更非同期→同期処理へ
    func getPlaybackRateDispatch(exifCompletionHandler: @escaping (_ rate: Float?) -> Void) -> Void{
        self.youtubeVideoView.getPlaybackRate({ playbackRate, error in
            if error == nil {
                exifCompletionHandler(playbackRate)
            }else{
                exifCompletionHandler(1.0)
            }
        })
        self.youtubeVideoView.getPlaybackRate()
    }
    // set Rate
    func setRate(setRate:Float){
        // ユーザーが変更しようとしてないので無視
        self.getPlaybackRateDispatch(exifCompletionHandler: {(rate) -> Void in
            let prevRate = rate!
            self.youtubeVideoView.setPlaybackRate(setRate)
            // setPlaybackRateの反映を待つ
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.getPlaybackRateDispatch(exifCompletionHandler: {(rate) -> Void in
                    let afterRate = rate!
                    if prevRate == afterRate {
                        nowRate = afterRate
                        self.rateMsgAlert(type:YoutubeRateMsgType.INCOMPATIBLE.rawValue,speed: setRate)
                    }else if setRate != afterRate{
                        nowRate = afterRate
                        self.rateMsgAlert(type:YoutubeRateMsgType.FAILURE.rawValue,speed: setRate)
                    }else{
                        nowRate = afterRate
                        self.rateMsgAlert(type:YoutubeRateMsgType.SUCCESS.rawValue,speed: setRate)
                    }
                })
            }
        })
    }
    // Rate変更時のメッセージだ仕分け
    func rateMsgAlert(type:Int,speed:Float){
        var alert = UIAlertController()
        var time = 1.0
        switch type {
        case YoutubeRateMsgType.INCOMPATIBLE.rawValue:
            alert = UIAlertController(title: RATE_SET_FAILURE_TITLE, message: RATE_SET_FAILURE_BODY+String(speed)+RATE_SET_FAILURE_BODY_A, preferredStyle: .alert)
            time = 1.2
        case YoutubeRateMsgType.FAILURE.rawValue:
            alert = UIAlertController(title: RATE_SET_FAILURE_BODY+String(speed)+RATE_SET_FAILURE_BODY_B+String(nowRate)+RATE_SET_FAILURE_BODY_DONE, message: "", preferredStyle: .alert)
            time = 1.2
        case YoutubeRateMsgType.SUCCESS.rawValue:
            alert = UIAlertController(title: "×" + String(nowRate), message: "", preferredStyle: .alert)
            time = 0.5
        case YoutubeRateMsgType.DEBUG.rawValue:
            alert = UIAlertController(title: debug_state, message: "DEBUG", preferredStyle: .alert)
            time = 1.0
        default:
            alert = UIAlertController(title: MV_PLAY_FAILURE_TITLE, message: RATE_SET_FAILURE_BODY_UNKNOWN, preferredStyle: .alert)
            time = 0.8
        }
        if type == YoutubeRateMsgType.SUCCESS.rawValue{
            showToastCenterMsg(messege:"×" + String(nowRate),time:time)
        }else{
            // アラート表示
            self.present(alert, animated: true, completion: {
                // アラートを自動で閉じる
                DispatchQueue.main.asyncAfter(deadline: .now() + time, execute: {
                    alert.dismiss(animated: true, completion: nil)
                    self.speedPicker.selectRow(mvSpeedList.index(of: nowRate) ?? mvSpeedRow, inComponent: 0, animated: true)
                })
            })
        }
    }
    
    /*******************************************************************
     ネットワーク確認処理
     *******************************************************************/
    func checkOffline(){
        // オフラインチェック
        if reachability.isReachable {
            errorView.isHidden = true
        }else{
            errorView.isHidden = false
        }
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
    /*******************************************************************
     広告（Admob）の処理
     *******************************************************************/
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        if YOUTUBE_PLAYER_FLG {
            if AVPlayerViewControllerManager.shared.controller.player != nil {
                AVPlayerViewControllerManager.shared.controller.player?.play()
                AVPlayerViewControllerManager.shared.controller.player?.rate = nowRate
            }
        } else {
            youtubeVideoView.playVideo()
        }
        loadInterstitial()
    }
    func loadInterstitial() {
        InterstitialAd.load(with: ADMOB_INTERSTITIAL_MV, request: Request()) { [weak self] ad, error in
            if let error = error {
                print("Failed to load interstitial: \(error.localizedDescription)")
                return
            }
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
        }
    }
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        self.dismiss(animated: true, completion: nil)
    }
    /*******************************************************************
     画面遷移時処理
     *******************************************************************/
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        youtubeVideoView.stopVideo()
//        if MVLoadTimer != nil{
//            // timerが起動中なら一旦破棄する
//            MVLoadTimer.invalidate()
//        }
        if AVPlayerViewControllerManager.shared.controller.player != nil{
            if AVPlayerViewControllerManager.shared.controller.player!.rate > Float(0) {
                MV_PLAY_flg = true
            }else{
                MV_PLAY_flg = false
            }
        }
    }
    // 端末の向きがかわったら呼び出される.
    @objc func onOrientationChange(notification: NSNotification){
        // 現在のデバイスの向きを取得.
        let deviceOrientation: UIDeviceOrientation!  = UIDevice.current.orientation        // 向きの判定.
        if deviceOrientation.isLandscape {
            //横向きの判定.
            nowViewDeirectionPort = false
        } else if deviceOrientation.isPortrait{
            //縦向きの判定.
            nowViewDeirectionPort = true
        }
    }
    // オブジェクト破棄時に監視を解除
    deinit {
//        self.youtubeWK.removeObserver(self, forKeyPath: "estimatedProgress")
//        self.youtubeWK.removeObserver(self, forKeyPath: "URL")
        //イベントリスナーの削除
        NotificationCenter.default.removeObserver(self)
    }
}

extension Array {
    mutating func oriShuffle() {
        for i in 0..<self.count {
            let j = Int(arc4random_uniform(UInt32(self.indices.last!)))
            if i != j {
                self.swapAt(i, j)
            }
        }
    }
    var oriShuffled: Array {
        var copied = Array<Element>(self)
        copied.oriShuffle()
        return copied
    }
}
/*******************************************************************
 YoutubeDelegate
 *******************************************************************/
extension YoutubePlayViewController: WKYTPlayerViewDelegate {
    func playerView(_ playerView: WKYTPlayerView, didChangeTo state: WKYTPlayerState) {
//        if MVLoadTimer != nil{
//            // timerが起動中なら一旦破棄する
//            MVLoadTimer.invalidate()
//        }
        youtubeVideoView.setShuffle(SHUFFLE_MV_FLG)
        switch state {
        case WKYTPlayerState.playing:
            self.waitView.isHidden = true
            hidePickerView.isHidden = true
            youtubeVideoView.isHidden = false
        case WKYTPlayerState.ended:
            if AD_DISPLAY_YOUTUBE_CONTENTS_NUM != 0 {
                if AD_DISPLAY_YOUTUBE_CONTENTS != false{
                    if let interstitial = interstitial, nowViewDeirectionPort {
                        youtubeVideoView.pauseVideo()
                        FROM_AD_FLG = true
                        interstitial.present(from: self)
                    }
                }
            }
        case WKYTPlayerState.buffering:
            // Timer End
            YOUTUBE_ONERROR_FLG = false
        case WKYTPlayerState.paused:
            hidePickerView.isHidden = true
        case WKYTPlayerState.queued:
            self.waitView.isHidden = true
            hidePickerView.isHidden = true
            youtubeVideoView.isHidden = false
        case WKYTPlayerState.unknown:break
        case WKYTPlayerState.unstarted: break
        default:break
        }
        self.waitView.isHidden = true // DEBUG
        // 動画再生回数をUserPropatyにSet
        Analytics.setUserProperty(String(MV_PLAY_NUM), forName: "動画再生回数")
    }
    func playerViewDidBecomeReady(_ playerView: WKYTPlayerView) {
        hidePickerView.isHidden = true
        youtubeVideoView.playVideo()
        youtubeVideoView.isHidden = false
        self.waitView.isHidden = true
        // Timer start
        YOUTUBE_ONERROR_FLG = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: {
            if self.YOUTUBE_ONERROR_FLG {
                showBigToastMsg(messege:MV_PLAY_FAILURE_CANT_PLAYTYPEMV,time:3.0, tab: COLOR_THEMA.HOME.rawValue)            }
        })
        self.getPlaybackRateDispatch(exifCompletionHandler: {(rate) -> Void in
            nowRate = rate!
            self.speedPicker.selectRow(mvSpeedList.index(of: nowRate) ?? mvSpeedRow, inComponent: 0, animated: true)
        })
    }
    func playerView(_ playerView: WKYTPlayerView, didChangeTo quality: WKYTPlaybackQuality) {
        hidePickerView.isHidden = false
    }
    func playerView(_ playerView: WKYTPlayerView, receivedError error: WKYTPlayerError) {
        print(error.rawValue)
    }
    func playerView(_ playerView: WKYTPlayerView, didPlayTime playTime: Float) {
        // Loop設定が単一だった場合は、その曲をもう一度再生
        playerView.getDuration({ duration, error in
            if error == nil {
                let seekToTime = Float(duration)
                if seekToTime - (0.6 * nowRate) <= playTime{
                    if repeatMVState == REPEAT_STATE_ONE {
                        playerView.seek(toSeconds: 0, allowSeekAhead:true)
                    }
                }
            }
        })
    }
    func playerViewPreferredWebViewBackgroundColor(_ playerView: WKYTPlayerView) -> UIColor { return .black }
    func playerViewPreferredInitialLoading(_ playerView: WKYTPlayerView) -> UIView? { return nil }
    func playerViewIframeAPIDidFailed(toLoad playerView: WKYTPlayerView){}

    /*******************************************************************
     Core Data
     *******************************************************************/
//    func playInWebView(){
//        // 再生不可能エラー
//        self.getPlaylistDispatch(exifCompletionHandler: {(playlist) -> Void in
//            self.getPlaylistIndexDispatch(exifCompletionHandler: {(playlistIndex) -> Void in
//                var VideoID = ""
//                var nextVideoID = ""
//
//                if playlist == [] {
//                    VideoID = self.youtubeVideoIdList[0]
//                    nextVideoID = ""
//                }else{
//                    VideoID = playlist[playlistIndex] as! String
//                    if playlist.count < playlistIndex + 1 + 1{
//                        nextVideoID = playlist[0] as! String
//                    }else{
//                        nextVideoID = playlist[playlistIndex + 1] as! String
//                    }
//                }
//                self.NowVideo = VideoID
//                self.youtubeUI.isHidden = false
//                self.youtubeVideoView.isHidden = true
//                self.kakeruLbl.isHidden = true
//                self.speedPicker.isHidden = true
//                self.playVideoUrl = "https://www.youtube.com/watch?v=" + VideoID + "&list=PLNyi762IjuQ6XOrmRsPPLLk3maYPDyUhI"// + VideoID// + "?version=3&playlist=" + nextVideoID
//                self.mplayVideoUrl = "https://m.youtube.com/watch?v=" + VideoID + "&list=PLNyi762IjuQ6XOrmRsPPLLk3maYPDyUhI"
//                let favoriteURL = NSURL(string: self.playVideoUrl)
//                let urlRequest = URLRequest(url: favoriteURL! as URL)
//                self.youtubeWK.load(urlRequest)
//            })
//        })
//    }
}

extension YoutubePlayViewController: WKUIDelegate, WKNavigationDelegate {

    // 監視対象の値に変化があった時に呼ばれる
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath {
        case "URL":
            // URLの変更時は、強制的に次の動画へ
            if let url = String(describing: change![.newKey]) as? String {
                // URLが同じもしくは、空だったらそのまま再生
                if oldUrl == "" {
                    oldUrl = url
                    break
                }
                // 同じ動画を再生するのならbreak
                if url.contains(self.NowVideo){
                    break
                }
                // 比較用URLの更新
                oldUrl = url
                // URLが異なっていたらwebView上で画面遷移が発生しているため次のMVを再生
                switch repeatMVState {
                    case REPEAT_STATE_NONE:break
                    case REPEAT_STATE_ALL:break
                    case REPEAT_STATE_ONE:
                        self.playVideoUrl = "https://www.youtube.com/watch?v=" + self.NowVideo
                        self.mplayVideoUrl = "https://m.youtube.com/watch?v=" + self.NowVideo
                        let favoriteURL = NSURL(string: self.playVideoUrl)
                        let urlRequest = URLRequest(url: favoriteURL! as URL)
//                        if self.baseWk.isDescendant(of: self.youtubeWK){
//                            self.youtubeWK.removeFromSuperview()
//                        }
//                        self.baseWk.addSubview(self.youtubeWK)
//                        self.youtubeWK.load(urlRequest)
                        return
                    default:break
                }
                //self.youtubeWK.removeFromSuperview()
                nextVideoPlay()
            }
            break
        case "estimatedProgress":break
            
            default:
                break
        }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Swift.Void) {
        decisionHandler(.allow)
    }
    // WKWebViewで読み込みが開始された際に実行する処理
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    }
    // WKWebViewで読み込みが完了した際に実行する処理
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.waitView.isHidden = true
    }
    // WKWebViewで読み込みが失敗した際に実行する処理
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    }
    // WKWebView内における3Dタッチを設定に関する設定(trueにすると有効になる)
    func webView(_ webView: WKWebView, shouldPreviewElement elementInfo: WKPreviewElementInfo) -> Bool {
        return false
    }
    // MARK: - リダイレクト
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation:WKNavigation!) {
    }
}
