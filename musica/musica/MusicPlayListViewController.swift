//
//  MusicPlayListViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2017/05/08.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import MediaPlayer
import AVFoundation
import CoreData
import GoogleMobileAds
import SWTableViewCell
import SwiftEntryKit

class MusicPlayListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate ,MPMediaPickerControllerDelegate, AVAudioPlayerDelegate, SWTableViewCellDelegate, FullScreenContentDelegate{

    /*
     ボタン関連
     */
    var size = CGSize()
    var nowBarBtn = 0
    
    // 音楽再生周りのボタン
    @IBOutlet weak var playBackBtn: UIButton!
    @IBOutlet weak var playBtn: UIButton!
    @IBOutlet weak var playNextBtn: UIButton!
    /*
     広告関連
     */
    @IBOutlet weak var bannerView: BannerView!
    var interstitial: InterstitialAd?

    /*
     音楽・table関連
     */
    @IBOutlet weak var BGImageView: UIImageView!
    @IBOutlet weak var BGEffectView: UIVisualEffectView!
    // MusicLibrary初期化フラグ
    let mMusicController = MusicController()
    //var playListNum : Int = 0
    var musicLibraryName : String = ""
    var iconName : String = ""
    var iconColorName : String = ""
    var newMusicLibraryCode : Int = 0
    @IBOutlet weak var musicLabraryTableview: UITableView!
    @IBOutlet weak var musicLibraryTitleBar: UINavigationBar!
    @IBOutlet weak var imageIconView: UIImageView!
    @IBOutlet weak var autoScrollTrackTitleLebel: CBAutoScrollLabel!
    var playedFlg = false
    var selectIndex = 0

    // ── 新デザイン ミニプレイヤーカード ──────────────────────────────────
    var miniPlayerCardShadow: UIView?       // シャドウラッパー
    var miniPlayerCard: UIView?             // clipsToBounds カード
    var miniPlayerBgImageView: UIImageView? // カード内背景アート
    var miniPlayerArtView: UIImageView?     // サムネイル
    var miniPlayerTitleLabel: UILabel?
    var miniPlayerArtistLabel: UILabel?
    var miniPlayerPlayPauseBtn: UIButton?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //端末によるサイズの計算とviewの設定
        self.title = musicLibraryName
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: " ", style: .plain, target: nil, action: nil)
        
        size = CGSize(width: myAppFrameSize.width, height: myAppFrameSize.height)
        if AD_DISPLAY_MUSICLIBRARYLIST_BANNER {
            bannerView.adUnitID = ADMOB_BANNER_ADUNIT_ID
            bannerView.rootViewController = self
            custumLoadBannerAd(bannerView: self.bannerView,setBannerView:self.view)
        }
        
        // テーブルデザイン
        musicLabraryTableview.backgroundColor = AppColor.background
        musicLabraryTableview.separatorColor = AppColor.separator

        // 長押し時の挙動を登録
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.cellLongPressed))
        longPressRecognizer.allowableMovement = 15
        longPressRecognizer.minimumPressDuration = 0.6
        musicLabraryTableview.addGestureRecognizer(longPressRecognizer)
        navigationItem.rightBarButtonItems = [makeAddTrackBtn()]
        
        // アイコン設定
        imageIconView.image = UIImage(named: "onpu_BL")
        imageIconView.contentMode = .center
        
        // ボタンを初期化
        playBackBtn.setImage(playBackLBtnImage.withRenderingMode(.alwaysTemplate), for: .normal)
        playBackBtn.tintColor = AppColor.accent
        playBtn.setImage(playBtnLImage.withRenderingMode(.alwaysTemplate), for: .normal)
        playBtn.tintColor = AppColor.accent
        playNextBtn.setImage(playNextLBtnImage.withRenderingMode(.alwaysTemplate), for: .normal)
        playNextBtn.tintColor = AppColor.accent

        /*
         音楽再生準備
         */
        autoScrollTrackTitleLebel.text = NOT_PLAYING_TRACK_TITLE   // 表示するテキスト
        autoScrollTrackTitleLebel.labelSpacing = 50;                          // 開始と終了の間間隔
        autoScrollTrackTitleLebel.pauseInterval = 1;                          // スクロール前の一時停止時間
        autoScrollTrackTitleLebel.scrollSpeed = 50.0;                         // スクロール速度
        autoScrollTrackTitleLebel.fadeLength = 10.0;                          // 左端と右端のフェードの長さ
        autoScrollTrackTitleLebel.font = AppFont.miniPlayerTitle

        // 新デザイン適用（viewDidLoad 最後に呼ぶ）
        redesignMiniPlayer()

        
        
        //showCustomNibView(attributes: attributes)
    }
    
    //--------------------------------
//    private func showCustomNibView(attributes: EKAttributes) {
//        SwiftEntryKit.display(entry: NibExampleView(), using: attributes)
//    }
    //--------------------------------
    
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if isDarkMode(vc: self){
            BGEffectView.effect = UIBlurEffect(style: .dark)
        }else{
            BGEffectView.effect = UIBlurEffect(style: .light)
        }
        musicLabraryTableview.reloadData()
    }
    /*******************************************************************
     画面描画時の処理
     *******************************************************************/
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // shadowPath を確定させてアニメーション中の再計算コストとチラつきを防ぐ
        if let shadow = miniPlayerCardShadow, shadow.bounds != .zero {
            shadow.layer.shadowPath = UIBezierPath(
                roundedRect: shadow.bounds, cornerRadius: 16
            ).cgPath
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // タブ切り替えアニメーション完了後にシャドウを復元（遷移中の縦線チラつき防止）
        guard let shadow = miniPlayerCardShadow else { return }
        shadow.layer.shadowOpacity = 0
        UIView.animate(withDuration: 0.2) {
            shadow.layer.shadowOpacity = 0.22
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 遷移アニメーション中はシャドウを非表示にしてチラつきを防ぐ
        miniPlayerCardShadow?.layer.shadowOpacity = 0
        selectMusicView.isHidden = true
        selectedTracks = [:]
        CUSTOM_LYBRARY_FROM_MUSICLIST = false
        LYRIC_RESULT_TEXT = ""
        // navigationbarの色設定
        self.navigationController?.navigationBar.isTranslucent = true
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        navAppearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: AppColor.textPrimary]
        self.navigationController?.navigationBar.standardAppearance = navAppearance
        self.navigationController?.navigationBar.scrollEdgeAppearance = navAppearance
        self.navigationController?.navigationBar.compactAppearance = navAppearance
        self.navigationController?.navigationBar.tintColor = AppColor.accent
        
        navigationItem.rightBarButtonItems = [makeAddTrackBtn()]
        
        if isDarkMode(vc: self){
            BGEffectView.effect = UIBlurEffect(style: .dark)
        }else{
            BGEffectView.effect = UIBlurEffect(style: .light)
        }
        // MusicLibrary 開いたことあるかフラグ
        if UserDefaults.standard.object(forKey: "music_library_fast_flg") == nil{
            UserDefaults.standard.set(true, forKey: "music_library_fast_flg")
            showToastMsg(messege:localText(key:"musiclibrary_fast_display_tuto"),time:3.0, tab: COLOR_THEMA.HOME.rawValue)
        }
        
        
        musicLabraryTableview.tableFooterView = UIView(frame: .zero)
        //RemoteController準備
        let session = AVAudioSession.sharedInstance()
        do {
            // バックグラウンドでも再生できるカテゴリに設定する
            try session.setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [])
            // sessionのアクティブ化
            try session.setActive(true)
        } catch  {
            // エラー処理
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
        
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(self.handleInterruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        center.addObserver(self, selector: #selector(self.audioSessionRouteChanged(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(handleRemotePlayPause), name: .musicaRemotePlayPause, object: nil)
        center.addObserver(self, selector: #selector(handleRemotePrevFromList), name: .musicaRemotePrev, object: nil)
        center.addObserver(self, selector: #selector(handleRemoteNextFromList), name: .musicaRemoteNext, object: nil)

        // 表示する音楽情報を更新
        displayMusicLibraryData.musicLibraryCode = newMusicLibraryCode
        if displayMusicLibraryData.musicLibraryCode != NowPlayingMusicLibraryData.musicLibraryCode || returnEditFlg {
            displayMusicLibraryData.trackData = []
            displayMusicLibraryData.nowPlayingLibrary = self.title!
            displayMusicLibraryData.trackData = getMusicLibraryTrackData(musicLibraryName:musicLibraryName)
            displayMusicLibraryData.trackDataShuffled = displayMusicLibraryData.trackData.oriShuffled
            if CUSTOM_LYBRARY_FLG && NowPlayingMusicLibraryData.nowPlaying != NOW_NOT_PLAYING {
                CUSTOM_LYBRARY_FLG = false
                NowPlayingMusicLibraryData.nowPlayingLibrary = displayMusicLibraryData.nowPlayingLibrary
                if SHUFFLE_FLG {
                    // 今再生していたものから、更新後のnowPlayingを更新
                    let _url = NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying].url
                    NowPlayingMusicLibraryData.trackData = displayMusicLibraryData.trackData
                    NowPlayingMusicLibraryData.trackDataShuffled = displayMusicLibraryData.trackDataShuffled
                    NowPlayingMusicLibraryData.nowPlaying = nowPlayTrackNumberInDisplay(url:_url)
                }else{
                    // 今再生していたものから、更新後のnowPlayingを更新
                    let _url = NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying].url
                    NowPlayingMusicLibraryData.trackData = displayMusicLibraryData.trackData
                    NowPlayingMusicLibraryData.trackDataShuffled = displayMusicLibraryData.trackDataShuffled
                    NowPlayingMusicLibraryData.nowPlaying = nowPlayTrackNumberInDisplay(url:_url)
                }
            }
        }
        // 強制終了対策
        if NowPlayingMusicLibraryData.nowPlaying == NOW_NOT_PLAYING{
            playBackBtn.isEnabled = false
            playNextBtn.isEnabled = false
        }else{
            playBackBtn.isEnabled = true
            playNextBtn.isEnabled = true
        }
        returnEditFlg = false
        musicLabraryTableview.reloadData()
        // audioが設定されてなかったらtableを更新
        if(audioPlayer == nil){
            return
        }else{
            //audioPlayer.delegate = nil
            audioPlayer.delegate = self   
        }
        // playerの更新
        //miniPlayerReload()
        // 再生状態の取得
        if NowPlayingMusicLibraryData.musicLibraryCode != NOW_NONE_MUSICLIBRARY_CODE {
            miniPlayerReload()
        }
        // 広告の準備
        loadInterstitial()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    /*******************************************************************
     table更新処理
     *******************************************************************/
    func swipeableTableViewCellShouldHideUtilityButtons( onSwipe cell: SWTableViewCell) -> Bool{
        return true
    }
    
    func swipeableTableViewCell( _ cell: SWTableViewCell,canSwipeTo canSwipeToState: SWCellState) -> Bool{
        return true
    }
    
    // セクションの個数
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    // セクション内の行数
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // 配列playListの値の個数
        return displayMusicLibraryData.trackData.count
    }
    
    // 1. 編集モードを許可するIndexPathの指定
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool{
        return true
    }
    // 2. ソートを許可するIndexPathの指定
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool{
        return true
    }
    // セル高さ
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 68
    }
    // tableフッターの高さを返却
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if AD_DISPLAY_MUSICLIBRARYLIST_BANNER{
            bannerView.isHidden = false
            return bannerView.frame.height
        }else{
            bannerView.isHidden = true
            return 0
        }
    }
    // tableフッターを返却
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    func makeEditBtn() -> UIBarButtonItem{
        let button = UIButton(type: UIButton.ButtonType.system)
        button.frame.size = CGSize(width: 80, height: 30)
        button.setTitleColor(AppColor.accent, for: UIControl.State.normal)
        button.layer.borderWidth = 1.0
        button.layer.borderColor = AppColor.accent.cgColor
        button.layer.cornerRadius = 5
        button.backgroundColor = AppColor.surface
        button.addTarget(self, action: #selector(self.editDoneBtnTapped), for: UIControl.Event.touchUpInside)
        button.setTitle(NAVUGATION_BTN_EDIT_END, for: UIControl.State.normal)
        let barButton = UIBarButtonItem(customView: button)
        nowBarBtn = 1
        return barButton
    }
    func makeAddTrackBtn() -> UIBarButtonItem {
        let button = UIButton(type: .system)
        if #available(iOS 15.0, *) {
            var cfg = UIButton.Configuration.plain()
            cfg.title = localText(key: "home_addtrack_btn")
            cfg.baseForegroundColor = AppColor.accent
            cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
                var a = attrs; a.font = AppFont.footnote; return a
            }
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12)
            button.configuration = cfg
        } else {
            button.frame.size = CGSize(width: 80, height: 30)
            button.setTitleColor(AppColor.accent, for: .normal)
            button.layer.cornerRadius = 5
            button.backgroundColor = AppColor.surface
            button.titleLabel?.font = AppFont.footnote
            button.setTitle(localText(key: "home_addtrack_btn"), for: .normal)
        }
        button.addTarget(self, action: #selector(self.addTrack), for: .touchUpInside)
        nowBarBtn = 0
        return UIBarButtonItem(customView: button)
    }
    @objc func addTrack(){
        CUSTOM_LYBRARY_FROM_MUSICLIST = true
        CUSTOM_LYBRARY_NAME = self.title!
        performSegue(withIdentifier: "toOSAlbumListfromList", sender: "")
    }
    // セルを作る
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        // テーブルのセルを参照する
        let cell = tableView.dequeueReusableCell(withIdentifier: "playData", for: indexPath) as! CustamPlayListTableViewCell
        // テーブルにmusicのデータを表示する
        let playData = displayMusicLibraryData.trackData[(indexPath as NSIndexPath).row]
        cell.trackTitleLabel.text = playData.title
        cell.trackTitleLabel.font = AppFont.headline
        cell.albumTitleLabel.text = playData.artist
        cell.trackNumLabel.text = String( indexPath.row + 1 )
        
        // audioPlayer が再生されていない、かつ表示しているライブラリと再生中のライブラリの曲が一致していなければ、gifは表示しない
        if (audioPlayer != nil && audioPlayer.isPlaying && displayMusicLibraryData.musicLibraryCode == NowPlayingMusicLibraryData.musicLibraryCode ){
            if SHUFFLE_FLG {
                if NowPlayingMusicLibraryData.nowPlaying != NOW_NOT_PLAYING && NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying].url == playData.url{
                    let gifData = darkPlayGif(vc : self)
//                    let jscript = "var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width'); document.getElementsByTagName('head')[0].appendChild(meta);"
//                    let userScript = WKUserScript(source: jscript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
//                    let wkUController = WKUserContentController()
//                    wkUController.addUserScript(userScript)
//                    let wkWebConfig = WKWebViewConfiguration()
//                    wkWebConfig.userContentController = wkUController
//                    //cell.animationGifWebView = WKWebView(frame: self.view.bounds, configuration: wkWebConfig)
                    cell.animationGifWebView.scrollView.isScrollEnabled = false
                    cell.animationGifWebView.load(gifData as Data, mimeType: "image/gif", characterEncodingName: "utf-8", baseURL: NSURL() as URL)
                    cell.trackNumLabel.isHidden = true
                    cell.animationGifWebView.isHidden = false
                }else{
                    cell.animationGifWebView.isHidden = true
                    cell.trackNumLabel.isHidden = false
                }
            }else {
                if NowPlayingMusicLibraryData.nowPlaying != NOW_NOT_PLAYING && NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying].url == playData.url{
                    let gifData = darkPlayGif(vc : self)
                    //cell.animationGifWebView.scalesPageToFit = true
//                    let jscript = "var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width'); document.getElementsByTagName('head')[0].appendChild(meta);"
//                    let userScript = WKUserScript(source: jscript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
//                    let wkUController = WKUserContentController()
//                    wkUController.addUserScript(userScript)
//                    let wkWebConfig = WKWebViewConfiguration()
//                    wkWebConfig.userContentController = wkUController
                    //cell.animationGifWebView = WKWebView(frame: self.view.bounds, configuration: wkWebConfig)
                    cell.animationGifWebView.scrollView.isScrollEnabled = false
                    cell.animationGifWebView.load(gifData as Data, mimeType: "image/gif", characterEncodingName: "utf-8", baseURL: NSURL() as URL)
                    cell.trackNumLabel.isHidden = true
                    cell.animationGifWebView.isHidden = false
                }else{
                    cell.animationGifWebView.isHidden = true
                    cell.trackNumLabel.isHidden = false
                }
            }
        
        }else{
            cell.animationGifWebView.isHidden = true
            cell.trackNumLabel.isHidden = false
        }
        cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
        cell.rightUtilityButtons = self.getRightUtilityButtonsToCell() as [AnyObject]
        // アクションを受け取るために設定
        cell.delegate = self
        return cell
    }
    //削除時に呼ばれるメソッド
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        // ライブラリ削除処理へ
        self.deleteTrack(indexPath_row: indexPath.row)
    }
    //並び替え時に呼ばれるメソッド
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath){
        // 音楽再生中であれば再生を止める TODO 削除されたライブラリ以外は止めなくても良いのでは？
        if audioPlayer != nil && audioPlayer.isPlaying{
            // 一旦音楽は止める
            audioPlayer.stop()
        }
        //移動されたデータを取得する。
        if NowPlayingMusicLibraryData.musicLibraryCode == displayMusicLibraryData.musicLibraryCode {
            let moveIdData = NowPlayingMusicLibraryData.trackData[sourceIndexPath.row]
            //元の位置のデータを配列から削除する。
            NowPlayingMusicLibraryData.trackData.remove(at: sourceIndexPath.row)
            //移動先の位置にデータを配列に挿入する。
            NowPlayingMusicLibraryData.trackData.insert(moveIdData , at:destinationIndexPath.row)
            displayMusicLibraryData.trackData = NowPlayingMusicLibraryData.trackData
        }else{
            let moveIdData = displayMusicLibraryData.trackData[sourceIndexPath.row]
            //元の位置のデータを配列から削除する。
            displayMusicLibraryData.trackData.remove(at: sourceIndexPath.row)
            //移動先の位置にデータを配列に挿入する。
            displayMusicLibraryData.trackData.insert(moveIdData , at:destinationIndexPath.row)
        }
        //NowPlayingMusicLibraryData.nowPlaying = 0
        musicLabraryTableview.reloadData()
    }
    
    /*
     tableのButtonを拡張する.
     */
    // 右からのスワイプ時のボタンの定義
    func getRightUtilityButtonsToCell()-> NSArray {
        let utilityButtons: NSMutableArray = NSMutableArray()
        utilityButtons.add(addUtilityButtonWithColor(color: AppColor.inactive, icon:UIImage(named: "edit")!))
        utilityButtons.add(addUtilityButtonWithColor(color: AppColor.destructive, icon:UIImage(named: "delete")!))
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
        let point = musicLabraryTableview.convert(cell.frame.origin, from: cell.superview)
        if let indexPath = musicLabraryTableview.indexPathForRow(at: point) {
            dlog("section: \(indexPath.section) - row: \(indexPath.row)")
            switch index {
            case 0:
                selectIndex = indexPath.row
                performSegue(withIdentifier: "toMusicSetting",sender: "")
            case 1:
                // アラートを作成
                let alert = UIAlertController(
                    title: "【" + displayMusicLibraryData.trackData[indexPath.row].title + "】" + localText(key:"musiclibrary_delete_conform_title"),
                    message: localText(key:"musictrack_delete_conform_title"),
                    preferredStyle: .alert)
                
                // アラートにボタンをつける
                alert.addAction(UIAlertAction(title: MESSAGE_YES, style: .default, handler: { action in
                    self.deleteTrack(indexPath_row: indexPath.row)
                }))
                
                alert.addAction(UIAlertAction(title: MESSAGE_NO, style: .default, handler: { action in
                    // NOが押されたら何もしない
                    return
                }))
                // アラート表示
                getForegroundViewController().present(alert, animated: true, completion: nil)
                
            default:
                dlog("other")
            }
        }
        
    }
        
    /* UITableViewDelegateデリゲートメソッド */
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath as IndexPath, animated: true)
        UISelectionFeedbackGenerator().selectionChanged()
        // 編集中であれば、再生しない
        if musicLabraryTableview.isEditing {
            return
        }
        // 再生中のライブラリが表示されているものが同じかチェック→違ったら更新
        if NowPlayingMusicLibraryData.musicLibraryCode != displayMusicLibraryData.musicLibraryCode || NowPlayingMusicLibraryData.nowPlayingLibrary != self.musicLibraryName{
            NowPlayingMusicLibraryData.musicLibraryCode = newMusicLibraryCode
            NowPlayingMusicLibraryData = NowPlayingData()
            NowPlayingMusicLibraryData = displayMusicLibraryData
            NowPlayingMusicLibraryData.nowPlayingLibrary = self.musicLibraryName
            NowPlayingMusicLibraryData.nowPlaying = indexPath.row
            NowPlayingMusicLibraryData.musicLibraryCode = displayMusicLibraryData.musicLibraryCode
            audioPlayer = nil
        }
        if NowPlayingMusicLibraryData.trackData.count != displayMusicLibraryData.trackData.count{
            NowPlayingMusicLibraryData.trackData = displayMusicLibraryData.trackData
            NowPlayingMusicLibraryData.trackDataShuffled = displayMusicLibraryData.trackDataShuffled
        }
        // 選択された音楽が再生可能かを確認
        if mMusicController.checkCanPlayMusic(playData : displayMusicLibraryData.trackData[indexPath.row]) != CODE_SUCCESS{
            showAlertMusicErrMsgOneOkBtn(title: ERR_DIALOGUE_TITLE_MUSIC_DATA_NONE,messege: ERR_DIALOGUE_MESSAGE_MUSIC_DATA_NONE)
            return
        }
        // 遷移回数取得
        if UserDefaults.standard.object(forKey: "accesMusicLibraryToPlayView") == nil{
            MUSIC_LIBRARY_TO_PLAYVIEW = 1
            UserDefaults.standard.set(MUSIC_LIBRARY_TO_PLAYVIEW, forKey: "accesMusicLibraryToPlayView")
        }else{
            MUSIC_LIBRARY_TO_PLAYVIEW = UserDefaults.standard.integer(forKey: "accesMusicLibraryToPlayView") + 1
            UserDefaults.standard.set(MUSIC_LIBRARY_TO_PLAYVIEW, forKey: "accesMusicLibraryToPlayView")
        }
        var forceADFlg = false
        if UserDefaults.standard.object(forKey: "accesMusicLibraryToPlayViewForceAD") == nil{
            UserDefaults.standard.set(forceADFlg, forKey: "accesMusicLibraryToPlayViewForceAD")
        }else{
            forceADFlg = UserDefaults.standard.bool(forKey: "accesMusicLibraryToPlayViewForceAD")
        }
        if ADApearFlg() {
            if MUSIC_LIBRARY_AD_INTERVAL == 0 {
                MUSIC_LIBRARY_AD_INTERVAL = 2
            }
            // 広告出現頻度
            if forceADFlg || MUSIC_LIBRARY_TO_PLAYVIEW % MUSIC_LIBRARY_AD_INTERVAL == 0{
                if interstitial != nil {
                    if interstitial != nil {
                        interstitial?.present(from: self)
                        forceADFlg = false
                        UserDefaults.standard.set(forceADFlg, forKey: "accesMusicLibraryToPlayViewForceAD")
                    }else{
                         UserDefaults.standard.set(true, forKey: "accesMusicLibraryToPlayViewForceAD")
                    }
                }else{
                    UserDefaults.standard.set(true, forKey: "accesMusicLibraryToPlayViewForceAD")
                }
            }
        }
        if SHUFFLE_FLG {
            for i in 0...NowPlayingMusicLibraryData.trackDataShuffled.count - 1 {
                if displayMusicLibraryData.trackData[indexPath.row].url == NowPlayingMusicLibraryData.trackDataShuffled[i].url{
                    newSelectPlayNum = i
                }
            }
        }else{
            newSelectPlayNum = indexPath.row
        }
        
        performSegue(withIdentifier: "toPlayMusicView",sender: "")
        
    }
    /*******************************************************************
     広告取得処理
     *******************************************************************/
    func loadInterstitial() {
        InterstitialAd.load(with: ADMOB_INTERSTITIAL_LIBRARY, request: Request()) { [weak self] ad, error in
            if let error = error { dlog("Interstitial failed to load: \(error)"); return }
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
        }
    }
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        loadInterstitial()
    }
    func adWillLeaveApplication(_ ad: FullScreenPresentingAd) {
        self.dismiss(animated: true, completion: nil)
    }
    /*******************************************************************
     ボタンタップ時処理
     *******************************************************************/
    //音楽再生ボタン
    @IBAction func playBtnTapped(_ sender: Any) {
        playBackBtn.isEnabled = true
        playNextBtn.isEnabled = true
        // 再生中のライブラリが表示されているものが同じかチェック→違ったら更新
        if NowPlayingMusicLibraryData.musicLibraryCode != displayMusicLibraryData.musicLibraryCode || audioPlayer == nil{
            NowPlayingMusicLibraryData = NowPlayingData()
            NowPlayingMusicLibraryData = displayMusicLibraryData
            NowPlayingMusicLibraryData.musicLibraryCode = newMusicLibraryCode
            // audioPlayer作成前もしくは他のmusiclibrary再生中なら、最初の曲を再生
            NowPlayingMusicLibraryData.nowPlaying = 0
            if SHUFFLE_FLG{
                if self.playMusicWrapper(playData: NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying]) == false {
                    //Viewの更新
                    NowPlayingMusicLibraryData.nowPlaying = 0
                    musicLabraryTableview.reloadData()
                    miniPlayerErrReload()
                    audioPlayer = nil
                    return
                }
            }else{
                if self.playMusicWrapper(playData: NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying]) == false {
                    //Viewの更新
                    NowPlayingMusicLibraryData.nowPlaying = 0
                    musicLabraryTableview.reloadData()
                    miniPlayerErrReload()
                    audioPlayer = nil
                    return
                }
            }
            // ボタンはストップボタン化
            playBtn.setImage(stopBtnLImage.withRenderingMode(.alwaysTemplate), for: .normal)
        }else{
            if (audioPlayer.isPlaying){
                // 一旦音楽は止める
                audioPlayer.stop()
                playBtn.setImage(playBtnLImage.withRenderingMode(.alwaysTemplate), for: .normal)
                
            }else{
                audioPlayer.play()
                playBtn.setImage(stopBtnLImage.withRenderingMode(.alwaysTemplate), for: .normal)
                miniPlayerReload()
            }
        }
        NowPlayingMusicLibraryData.nowPlayingLibrary = self.musicLibraryName
        // アニメーション
        tappedAnimation(tappedBtn: playBtn)
        // 新カードの再生/停止アイコンを即時更新
        let ppCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        let ppSymbol = (audioPlayer?.isPlaying ?? false) ? "pause.fill" : "play.fill"
        miniPlayerPlayPauseBtn?.setImage(UIImage(systemName: ppSymbol, withConfiguration: ppCfg), for: .normal)
        musicLabraryTableview.reloadData()
    }

    // 「次の曲へ」ボタンタップ時
    @IBAction func playNextBtnTapped(_ sender: Any) {
        // 再生中のライブラリが表示されているものが同じかチェック→違ったら更新
        NEXT_TAP_FLG = true
        self.desideNextPlayMusic(next: true)
        // 再生可能かをチェック
        if SHUFFLE_FLG {
            if self.playMusicWrapper(playData: NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying]) == false {
                //Viewの更新
                NowPlayingMusicLibraryData.nowPlaying = 0
                musicLabraryTableview.reloadData()
                miniPlayerErrReload()
                audioPlayer = nil
                return
            }
        }else {
            if self.playMusicWrapper(playData: NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying]) == false {
                //Viewの更新
                NowPlayingMusicLibraryData.nowPlaying = 0
                musicLabraryTableview.reloadData()
                miniPlayerErrReload()
                audioPlayer = nil
                return
            }
            
        }
        playBtn.setImage(stopBtnLImage.withRenderingMode(.alwaysTemplate), for: .normal)
        tappedAnimation(tappedBtn: playNextBtn)
    }
    
    // 「前の曲へ」ボタンタップ時
    @IBAction func playBackBtnTapped(_ sender: Any) {
        if  audioPlayer != nil && NowPlayingMusicLibraryData.musicLibraryCode == displayMusicLibraryData.musicLibraryCode {
            if audioPlayer.currentTime > 3 {
                tappedAnimation(tappedBtn: playBackBtn)
                audioPlayer.currentTime = 0
                return
            }
        }
        // 再生中のライブラリが表示されているものが同じかチェック→違ったら更新
        self.desideNextPlayMusic(next: false)
        // 再生可能かをチェック
        if SHUFFLE_FLG {
            if self.playMusicWrapper(playData: NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying]) == false {
                //Viewの更新
                NowPlayingMusicLibraryData.nowPlaying = 0
                musicLabraryTableview.reloadData()
                miniPlayerErrReload()
                audioPlayer = nil
                return
            }
        }else {
            if self.playMusicWrapper(playData: NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying]) == false {
                //Viewの更新
                NowPlayingMusicLibraryData.nowPlaying = 0
                musicLabraryTableview.reloadData()
                miniPlayerErrReload()
                audioPlayer = nil
                return
            }
            
        }
        playBtn.setImage(stopBtnLImage.withRenderingMode(.alwaysTemplate), for: .normal)
        tappedAnimation(tappedBtn: playBackBtn)
    }
    // リモート通知ハンドラ（練習タブ・ディクテーション画面からの操作）
    // PlayMusicVCが nav スタックにいる場合はそちらに任せて二重処理を防ぐ
    @objc private func handleRemotePlayPause() {
        guard !(navigationController?.topViewController is PlayMusicViewController) else { return }
        playBtnTapped(self)
        miniPlayerReload()
    }

    @objc private func handleRemotePrevFromList() {
        guard !(navigationController?.topViewController is PlayMusicViewController) else { return }
        prevMusicPlay()
    }

    @objc private func handleRemoteNextFromList() {
        guard !(navigationController?.topViewController is PlayMusicViewController) else { return }
        nextMusicPlay()
    }

    // 次の曲再生
    @objc func nextMusicPlay(){
        self.desideNextPlayMusic(next: true)
        // 再生可能かをチェック
        if SHUFFLE_FLG {
            if self.playMusicWrapper(playData: NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying]) == false {
                //Viewの更新
                NowPlayingMusicLibraryData.nowPlaying = 0
                musicLabraryTableview.reloadData()
                miniPlayerErrReload()
                audioPlayer = nil
                return
            }
        }else {
            if self.playMusicWrapper(playData: NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying]) == false {
                //Viewの更新
                NowPlayingMusicLibraryData.nowPlaying = 0
                musicLabraryTableview.reloadData()
                miniPlayerErrReload()
                audioPlayer = nil
                return
            }
            
        }
    }
    // 前の曲再生
    @objc func prevMusicPlay(){
        
        if audioPlayer != nil && NowPlayingMusicLibraryData.musicLibraryCode == displayMusicLibraryData.musicLibraryCode{
            if audioPlayer.currentTime > 3 {
                audioPlayer.currentTime = 0
                return
            }
        }
        self.desideNextPlayMusic(next: false)
        // 再生可能かをチェック
        if SHUFFLE_FLG {
            if self.playMusicWrapper(playData: NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying]) == false {
                //Viewの更新
                NowPlayingMusicLibraryData.nowPlaying = 0
                musicLabraryTableview.reloadData()
                miniPlayerErrReload()
                audioPlayer = nil
                return
            }
        }else {
            if self.playMusicWrapper(playData: NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying]) == false {
                //Viewの更新
                NowPlayingMusicLibraryData.nowPlaying = 0
                musicLabraryTableview.reloadData()
                miniPlayerErrReload()
                audioPlayer = nil
                return
            }
            
        }
    }
    @objc func play (){
        NowPlayingMusicLibraryData.musicLibraryCode = newMusicLibraryCode
        if audioPlayer == nil{
            NowPlayingMusicLibraryData = NowPlayingData()
            NowPlayingMusicLibraryData = displayMusicLibraryData
            
            // audioPlayer作成前もしくは他のmusiclibrary再生中なら、最初の曲を再生
            NowPlayingMusicLibraryData.nowPlayingLibrary = self.musicLibraryName
            NowPlayingMusicLibraryData.nowPlaying = 0
            if SHUFFLE_FLG {
                
                if self.playMusicWrapper(playData: NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying]) == false{
                    //Viewの更新
                    NowPlayingMusicLibraryData.nowPlaying = 0
                    musicLabraryTableview.reloadData()
                    miniPlayerErrReload()
                    return
                }
            }else{
                if self.playMusicWrapper(playData: NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying]) == false{
                    //Viewの更新
                    NowPlayingMusicLibraryData.nowPlaying = 0
                    musicLabraryTableview.reloadData()
                    miniPlayerErrReload()
                    return
                }            }
            // ボタンはストップボタン化
            playBtn.setImage(stopBtnLImage.withRenderingMode(.alwaysTemplate), for: .normal)
            return
        }
        audioPlayer.play()
        
    }
    @objc func stop (){
        if audioPlayer == nil{
            return
        }
        audioPlayer.stop()
    }
    // 「編集完了」ボタンタップ時
    @objc func editDoneBtnTapped() {
        musicLabraryTableview.isEditing = false
        navigationItem.rightBarButtonItems = [makeAddTrackBtn()]
        // プレイヤー初期化
        audioPlayer = nil
        // アイコン設定
        imageIconView.image = UIImage(named: "onpu_BL")
        imageIconView.contentMode = .center
        
        // ボタンを初期化
        playBackBtn.setImage(playBackLBtnImage.withRenderingMode(.alwaysTemplate), for: .normal)
        playBtn.setImage(playBtnLImage.withRenderingMode(.alwaysTemplate), for: .normal)
        playNextBtn.setImage(playNextLBtnImage.withRenderingMode(.alwaysTemplate), for: .normal)
        
        autoScrollTrackTitleLebel.text = NOT_PLAYING_TRACK_TITLE
        resetMiniPlayerCard()

        //テーブルの再読み込み
        musicLabraryTableview.reloadData()
        // DB保存
        let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
        let context:NSManagedObjectContext = appDelegate.managedObjectContext
        let fetchRequest:NSFetchRequest<MusicModel> = MusicModel.fetchRequest()
        let predicate = NSPredicate(format:"%K = %@","musicLibraryName",self.title!)
        fetchRequest.predicate = predicate
        let fetchData = try! context.fetch(fetchRequest)
        
        DispatchQueue.main.async {
            // 並び替え後のデータを保存
            if(!fetchData.isEmpty){
                for i in 0..<displayMusicLibraryData.trackData.count{
                    fetchData[i].indicatoryNum = Int16(i)
                    fetchData[i].albumTitle = displayMusicLibraryData.trackData[i].albumName
                    fetchData[i].artist = displayMusicLibraryData.trackData[i].artist
                    if displayMusicLibraryData.trackData[i].artworkImg == nil {
                        fetchData[i].artworkData = nil
                    } else{
                        fetchData[i].artworkData = displayMusicLibraryData.trackData[i].artworkImg!.pngData()! as NSData as Data
                    }
                    fetchData[i].lyric = displayMusicLibraryData.trackData[i].lyric
                    fetchData[i].musicLibraryName = self.title
                    fetchData[i].trackTitle = displayMusicLibraryData.trackData[i].title
                    fetchData[i].url = String(describing: displayMusicLibraryData.trackData[i].url!)
                    
                }
                do{
                    try context.save()
                }catch{
                    dlog(error)
                }
            }
        }
    }
    /* 長押しした際に呼ばれるメソッド */
    @objc func cellLongPressed(recognizer: UILongPressGestureRecognizer) {
        if musicLabraryTableview.isEditing == true{
            //musictableview.isEditing = false
        }else{
            musicLabraryTableview.isEditing = true
            // プレイヤー初期化
            audioPlayer = nil
            // アイコン設定
            imageIconView.image = UIImage(named: "onpu_BL")
            imageIconView.contentMode = .center
            // ボタンを初期化
            playBackBtn.setImage(playBackLBtnImage.withRenderingMode(.alwaysTemplate), for: .normal)
            playBtn.setImage(playBtnLImage.withRenderingMode(.alwaysTemplate), for: .normal)
            playNextBtn.setImage(playNextLBtnImage.withRenderingMode(.alwaysTemplate), for: .normal)
            autoScrollTrackTitleLebel.text = NOT_PLAYING_TRACK_TITLE
            resetMiniPlayerCard()
            // 編集完了ボタンの有効化
            navigationItem.rightBarButtonItems = [makeEditBtn()]
            musicLabraryTableview.reloadData()
        }
    }
    
    @IBAction func allowTapped(_ sender: Any) {
        // 編集中であれば、再生しない
        if musicLabraryTableview.isEditing {
            showAlertMsgOneOkBtn(title: CANT_PLAY_MUSIC_NOW_EDIT,messege: "")
            return

        }
        // 再生中のライブラリが表示されているものが同じかチェック→違ったら更新
        if NowPlayingMusicLibraryData.musicLibraryCode != displayMusicLibraryData.musicLibraryCode {
            NowPlayingMusicLibraryData = NowPlayingData()
            NowPlayingMusicLibraryData = displayMusicLibraryData
            NowPlayingMusicLibraryData.nowPlaying = -1
            NowPlayingMusicLibraryData.musicLibraryCode = newMusicLibraryCode
            NowPlayingMusicLibraryData.nowPlayingLibrary = self.musicLibraryName
            newSelectPlayNum = 0
        }else{
            newSelectPlayNum = NowPlayingMusicLibraryData.nowPlaying
            NowPlayingMusicLibraryData.nowPlayingLibrary = self.musicLibraryName
        }
        if newSelectPlayNum == NOW_NOT_PLAYING{
            newSelectPlayNum = 0
        }
        autoScrollTrackTitleLebel.text = NowPlayingMusicLibraryData.trackData[newSelectPlayNum].title
        // 選択された音楽が再生可能かを確認
        if mMusicController.checkCanPlayMusic(playData : NowPlayingMusicLibraryData.trackData[newSelectPlayNum]) != CODE_SUCCESS{
            showAlertMusicErrMsgOneOkBtn(title: ERR_DIALOGUE_TITLE_MUSIC_DATA_NONE,messege: ERR_DIALOGUE_MESSAGE_MUSIC_DATA_NONE)
            return
        }
        performSegue(withIdentifier: "toPlayMusicView",sender: "")
    }

    /*******************************************************************
     音楽制御処理
     *******************************************************************/
    // 今表示されているライブラリから、再生中の音楽を探す。
    func nowPlayTrackNumberInDisplay(url:URL?) -> Int {
        var index = 0
        if SHUFFLE_FLG {
            for _track in displayMusicLibraryData.trackDataShuffled {
                if url == _track.url {
                    return index
                }
                index = index + 1
            }
        }else{
            for _track in displayMusicLibraryData.trackData {
                if url == _track.url {
                    return index
                }
                index = index + 1
            }
        }
        return -1
    }
    //  音楽再生のためのラッパー関数
    func playMusicWrapper(playData: TrackData) -> Bool{
        // 編集中であれば、再生しない
        if musicLabraryTableview.isEditing {
            showAlertMsgOneOkBtn(title: CANT_PLAY_MUSIC_NOW_EDIT,messege: "")
            imageIconView.image = UIImage(named: "onpu_BL")
            imageIconView.contentMode = .center
            autoScrollTrackTitleLebel.text = NOT_PLAYING_TRACK_TITLE
            audioPlayer = nil
            miniPlayerErrReload()
            return false
        }
        // 再生可能かを確認
        if mMusicController.checkCanPlayMusic(playData: playData) != CODE_SUCCESS || mMusicController.playMusic(playData: playData,vc: self) != CODE_SUCCESS{
            showAlertMusicErrMsgOneOkBtn(title: ERR_DIALOGUE_TITLE_MUSIC_DATA_NONE,messege: ERR_DIALOGUE_MESSAGE_MUSIC_DATA_NONE)
            return false
        }
        //audioPlayer.delegate = nil
        audioPlayer.delegate = self
        
        //再生時の設置
        autoScrollTrackTitleLebel.text = playData.title
        audioPlayer.volume = volume
        let speed = speedList[speedRow] * 10
        audioPlayer.rate = Float(round(speed) / 10)
        
        // Viewの更新
        miniPlayerReload()
        //musicLabraryTableview.reloadData()
        return true
    }
    
    // 再生終了時の呼び出しメソッド
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // 最後の曲再生中かつ、リピートフラグが立っていなければ終了
        if NowPlayingMusicLibraryData.nowPlaying == NowPlayingMusicLibraryData.trackData.count - 1 && repeatState == REPEAT_STATE_NONE{
            if repeatState != REPEAT_STATE_ALL {
                newSelectPlayNum = 0
                // プレイヤー初期化
                if audioPlayer != nil {
                    audioPlayer.stop()
                }
                // アイコン設定
                imageIconView.image = UIImage(named: "onpu_BL")
                imageIconView.contentMode = .center
                // ボタンを初期化
                playBackBtn.setImage(playBackLBtnImage.withRenderingMode(.alwaysTemplate), for: .normal)
                playBtn.setImage(playBtnLImage.withRenderingMode(.alwaysTemplate), for: .normal)
                playNextBtn.setImage(playNextLBtnImage.withRenderingMode(.alwaysTemplate), for: .normal)
                autoScrollTrackTitleLebel.text = NOT_PLAYING_TRACK_TITLE
                //テーブルの再読み込み
                musicLabraryTableview.reloadData()
                return
            }
        }
        self.desideNextPlayMusic(next: true)
        // 再生可能かをチェック
        if SHUFFLE_FLG {
            if self.playMusicWrapper(playData: NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying]) == false {
                //Viewの更新
                NowPlayingMusicLibraryData.nowPlaying = 0
                musicLabraryTableview.reloadData()
                miniPlayerErrReload()
                if audioPlayer != nil {
                    audioPlayer.stop()
                }
                return
            }
        }else {
            if self.playMusicWrapper(playData: NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying]) == false {
                //Viewの更新
                NowPlayingMusicLibraryData.nowPlaying = 0
                musicLabraryTableview.reloadData()
                miniPlayerErrReload()
                if audioPlayer != nil {
                    audioPlayer.stop()
                }
                return
            }
        }
        playBtn.setImage(stopBtnLImage.withRenderingMode(.alwaysTemplate), for: .normal)
    }
    
    // 次に再生する曲をセットする
    func desideNextPlayMusic(next : Bool) {
        if NowPlayingMusicLibraryData.musicLibraryCode != displayMusicLibraryData.musicLibraryCode {
            NowPlayingMusicLibraryData = NowPlayingData()
            NowPlayingMusicLibraryData = displayMusicLibraryData
            NowPlayingMusicLibraryData.nowPlaying = 0
            NowPlayingMusicLibraryData.nowPlayingLibrary = self.musicLibraryName
        }
        
        NowPlayingMusicLibraryData.musicLibraryCode = newMusicLibraryCode
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
    }
    
    // 上部のミニplayer更新
    func miniPlayerReload(){
        DispatchQueue.main.async {
            // 再生中のライブラリが表示されているものが同じかチェック→違ったら表示をデフォルトに戻す。
            if NowPlayingMusicLibraryData.musicLibraryCode == displayMusicLibraryData.musicLibraryCode {
                if SHUFFLE_FLG {
                    self.autoScrollTrackTitleLebel.text = NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying].title
                    // ボタンの設定
                    if audioPlayer != nil && audioPlayer.isPlaying{
                        self.playBtn.setImage(stopBtnLImage.withRenderingMode(.alwaysTemplate), for: .normal)
                    }else{
                        self.playBtn.setImage(playBtnLImage.withRenderingMode(.alwaysTemplate), for: .normal)
                        
                    }
                    self.imageIconView.contentMode = .scaleAspectFit
                    if NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying].artworkImg ==  nil{
                        self.imageIconView.image = UIImage(named: "onpu_BL")
                        self.BGImageView.image = UIImage(named: "onpu_BL")
                        self.imageIconView.contentMode = .center
                    } else {
                        self.imageIconView.image = NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying].artworkImg
                        self.BGImageView.image = NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying].artworkImg
                        //ここでtextの更新
                        //playingMusicNameLabel.morphingEffect = .pixelate
                        self.autoScrollTrackTitleLebel.text = ""
                        self.autoScrollTrackTitleLebel.text = NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying].title
                    }
                }else{
                    
                    self.autoScrollTrackTitleLebel.text = NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying].title
                    // ボタンの設定
                    if audioPlayer != nil && audioPlayer.isPlaying{
                        self.playBtn.setImage(stopBtnLImage.withRenderingMode(.alwaysTemplate), for: .normal)
                    }else{
                        self.playBtn.setImage(playBtnLImage.withRenderingMode(.alwaysTemplate), for: .normal)
                        
                    }
                    self.imageIconView.contentMode = .scaleAspectFit
                    if NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying].artworkImg ==  nil{
                        self.imageIconView.image = UIImage(named: "onpu_BL")
                        self.BGImageView.image = UIImage(named: "onpu_BL")
                        self.imageIconView.contentMode = .center
                    } else {
                        self.imageIconView.image = NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying].artworkImg
                        self.BGImageView.image = NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying].artworkImg
                        //ここでtextの更新
                        self.autoScrollTrackTitleLebel.text = ""
                        self.autoScrollTrackTitleLebel.text = NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying].title
                    }
                }
            }else{
                self.autoScrollTrackTitleLebel.text = NOT_PLAYING_TRACK_TITLE
                self.playBtn.setImage(playBtnLImage.withRenderingMode(.alwaysTemplate), for: .normal)
                self.imageIconView.image = UIImage(named: "onpu_BL")
                self.imageIconView.contentMode = .center
            }
            // ── 新カード同期 ──────────────────────────────────────────────
            let isPlaying = audioPlayer != nil && audioPlayer.isPlaying
            if NowPlayingMusicLibraryData.musicLibraryCode == displayMusicLibraryData.musicLibraryCode,
               NowPlayingMusicLibraryData.nowPlaying >= 0 {
                let track = SHUFFLE_FLG
                    ? NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying]
                    : NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying]
                self.syncMiniPlayerCard(artworkImg: track.artworkImg,
                                        title: track.title,
                                        artist: track.artist,
                                        isPlaying: isPlaying)
            } else {
                self.resetMiniPlayerCard()
            }
            NotificationCenter.default.post(name: .musicaTrackChanged, object: nil)
            self.musicLabraryTableview.reloadData()
        }
    }

    // 上部のミニplayer更新(エラー用)
    func miniPlayerErrReload(){
        if SHUFFLE_FLG {
            if audioPlayer != nil{
                autoScrollTrackTitleLebel.text = NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying].title
            }
            // ボタンの設定
            playBtn.setImage(playBtnLImage.withRenderingMode(.alwaysTemplate), for: .normal)
            imageIconView.contentMode = .scaleAspectFit
            if NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying].artworkImg ==  nil || audioPlayer == nil{
                imageIconView.image = UIImage(named: "onpu_BL")
                self.BGImageView.image = UIImage(named: "onpu_BL")
                imageIconView.contentMode = .center
                
            } else {
                imageIconView.image = NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying].artworkImg
                //ここでtextの更新
                //playingMusicNameLabel.morphingEffect = .pixelate
                autoScrollTrackTitleLebel.text = ""
                autoScrollTrackTitleLebel.text = NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying].title
            }
        }else{
            if audioPlayer != nil{
                autoScrollTrackTitleLebel.text = NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying].title
            }
            // ボタンの設定
            playBtn.setImage(playBtnLImage.withRenderingMode(.alwaysTemplate), for: .normal)
            imageIconView.contentMode = .scaleAspectFit
            if NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying].artworkImg ==  nil || audioPlayer == nil{
                imageIconView.image = UIImage(named: "onpu_BL")
                self.BGImageView.image = UIImage(named: "onpu_BL")
                imageIconView.contentMode = .center
                
            } else {
                imageIconView.image = NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying].artworkImg
                //ここでtextの更新
                autoScrollTrackTitleLebel.text = ""
                autoScrollTrackTitleLebel.text = NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying].title
            }
        }

        // ── 新カード同期（エラー時: isPlaying=false） ──────────────────
        if NowPlayingMusicLibraryData.nowPlaying >= 0 {
            let track = SHUFFLE_FLG
                ? NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying]
                : NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying]
            syncMiniPlayerCard(artworkImg: audioPlayer != nil ? track.artworkImg : nil,
                               title: audioPlayer != nil ? track.title : NOT_PLAYING_TRACK_TITLE,
                               artist: audioPlayer != nil ? track.artist : "",
                               isPlaying: false)
        } else {
            resetMiniPlayerCard()
        }
    }

    /*******************************************************************
     音楽削除時の処理
     *******************************************************************/
    func deleteTrack(indexPath_row: Int) {
        // 音楽再生中であれば再生を止める TODO 削除された音楽以外は止めなくても良いのでは？
        audioPlayer = nil
        NowPlayingMusicLibraryData.nowPlaying = 0
        //音楽を削除する
        let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
        let musicContext:NSManagedObjectContext = appDelegate.managedObjectContext
        let musicFetchRequest:NSFetchRequest<MusicModel> = MusicModel.fetchRequest()
        
        var musicPredicate = [NSPredicate]()
        musicPredicate.append(NSPredicate(format:"%K = %@","trackTitle",displayMusicLibraryData.trackData[indexPath_row].title))
        musicPredicate.append(NSPredicate(format:"%K = %@","musicLibraryName",self.title!))
        musicFetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: musicPredicate)
        let musicFetchData = try! musicContext.fetch(musicFetchRequest)
        if(!musicFetchData.isEmpty){
            for i in 0..<musicFetchData.count{
                let deleteObject = musicFetchData[i] as MusicModel
                musicContext.delete(deleteObject)
            }
            do{
                try musicContext.save()
                //元の位置のデータを配列から削除する。
                displayMusicLibraryData.trackData.remove(at: indexPath_row)
                displayMusicLibraryData.trackDataShuffled = displayMusicLibraryData.trackData.oriShuffled
                //移動されたデータから、NowPlayingMusicLibraryDataうを再生成する。
                if NowPlayingMusicLibraryData.musicLibraryCode == displayMusicLibraryData.musicLibraryCode {
                    NowPlayingMusicLibraryData = displayMusicLibraryData
                }
            }catch{
                dlog(error)
            }
        }
        // 登録されている「音楽」数も更新
        let appDelegateC:AppDelegate = UIApplication.shared.delegate as! AppDelegate
        let contextC:NSManagedObjectContext = appDelegateC.managedObjectContext
        let fetchRequestC:NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
        let fetchDataC = try! contextC.fetch(fetchRequestC)
        if(!fetchDataC.isEmpty){
            for i in 0..<fetchDataC.count{
                if fetchDataC[i].musicLibraryName == self.title{
                    
                    fetchDataC[i].trackNum = Int16(displayMusicLibraryData.trackData.count)
                }
            }
        }
        
        if displayMusicLibraryData.trackData.count == 0 {
            //MusicLibraryを削除する
            let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
            let musicContext:NSManagedObjectContext = appDelegate.managedObjectContext
            let musicFetchRequest:NSFetchRequest<MusicModel> = MusicModel.fetchRequest()
            let musicPredicate = NSPredicate(format:"%K = %@","musicLibraryName",self.title!)
            musicFetchRequest.predicate = musicPredicate
            let musicFetchData = try! musicContext.fetch(musicFetchRequest)
            
            //MusicLibraryのデータを削除する
            let musicLibraryContext:NSManagedObjectContext = appDelegate.managedObjectContext
            let musicLibraryFetchRequest:NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
            let musicLibraryPredicate = NSPredicate(format:"%K = %@","musicLibraryName",self.title!)
            musicLibraryFetchRequest.predicate = musicLibraryPredicate
            let musicLibraryFetchData = try! musicLibraryContext.fetch(musicLibraryFetchRequest)
            
            if(!musicFetchData.isEmpty){
                for i in 0..<musicFetchData.count{
                    let deleteObject = musicFetchData[i] as MusicModel
                    musicContext.delete(deleteObject)
                }
            }
            if(!musicLibraryFetchData.isEmpty){
                for i in 0..<musicLibraryFetchData.count{
                    let deleteObject = musicLibraryFetchData[i] as MusicLibraryModel
                    musicLibraryContext.delete(deleteObject)
                }
            }
            do{
                try musicContext.save()
                try musicLibraryContext.save()
                try contextC.save()
                
            }catch{
                dlog(error)
            }
            
            // TOP画面へ遷移
            let storyboard: UIStoryboard = self.storyboard!
            let nextView = storyboard.instantiateViewController(withIdentifier: "topView")
            nextView.modalPresentationStyle = .fullScreen
            // NowPlayingMusicLibraryDataも初期化する
            NowPlayingMusicLibraryData = NowPlayingData()
            self.present(nextView, animated: true, completion: nil)
        }
        do{
            try musicContext.save()
            try contextC.save()
            
        }catch{
            dlog(error)
            return
        }
        
        // アイコン設定
        self.imageIconView.image = UIImage(named: "onpu_BL")
        self.imageIconView.contentMode = .center
        
        // ボタンを初期化
        self.playBackBtn.setImage(playBackLBtnImage.withRenderingMode(.alwaysTemplate), for: .normal)
        self.playBtn.setImage(playBtnLImage.withRenderingMode(.alwaysTemplate), for: .normal)
        self.playNextBtn.setImage(playNextLBtnImage.withRenderingMode(.alwaysTemplate), for: .normal)
        self.autoScrollTrackTitleLebel.text = NOT_PLAYING_TRACK_TITLE
        //テーブルの再読み込み
        self.musicLabraryTableview.reloadData()
        showToastMsg(messege:LISTMODE_LIVRARY_DELETE_TRACK,time:2.0, tab: COLOR_THEMA.HOME.rawValue)
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
                }else{
                    if playedFlg {
                        playedFlg = false
                        //audioPlayer.play()
                    }
                }
                miniPlayerReload()
                break
            case .ended:
                // interruptionが終了した時の処理
                
                if(audioPlayer == nil){
                }else{
                    playedFlg = true
                    audioPlayer.stop()
                }
                miniPlayerReload()
                break
                
            }
        }
        
    }
    // Audio Session Route Change : ルートが変化した(ヘッドセットが抜き差しされた)
    @objc func audioSessionRouteChanged(_ notification: Notification) {
        let reasonObj = (notification as NSNotification).userInfo![AVAudioSessionRouteChangeReasonKey] as! NSNumber
        if let reason = AVAudioSession.RouteChangeReason(rawValue: reasonObj.uintValue) {
            switch reason {
            case .newDeviceAvailable:
                // 新たなデバイスのルートが使用可能になった
                if audioPlayer != nil {
                    if playedFlg {
                        playedFlg = false
                        audioPlayer.play()
                    }
                }
                break
            case .oldDeviceUnavailable:
                playedFlg = false
                if audioPlayer != nil{
                    if audioPlayer.isPlaying {
                        playedFlg = true
                        audioPlayer.stop()
                    }
                }
                break
            default:
                break
            }
            miniPlayerReload()
        }
        
    }
    
    /*******************************************************************
     画面遷移時処理
     *******************************************************************/
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 遷移アニメーション中はシャドウを非表示にしてチラつきを防ぐ
        miniPlayerCardShadow?.layer.shadowOpacity = 0
        // 編集完了ボタンの無効化
        navigationItem.rightBarButtonItems = [makeAddTrackBtn()]
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //Track 一覧画面へ
        if segue.identifier == "toPlayMusicView" {
            // PlayMusicViewControllerをインスタンス化
            let secondVc = segue.destination as! PlayMusicViewController
            // 値を渡す
            secondVc.musicLibraryName = musicLibraryName
            // 遷移前の再生状態を保持（停止中なら再生を開始しない）
            secondVc.preservePlayState = !(audioPlayer?.isPlaying ?? false)
            mMusicController.commandAllRemove()
        }else if segue.identifier == "toMusicSetting" {
            // musicLyricEditViewControllerをインスタンス化
            let secondVc = segue.destination as! scanViewController
            secondVc.EDIT_FLG = true
            secondVc.title = displayMusicLibraryData.trackData[selectIndex].title
            secondVc.editTrackUrl = displayMusicLibraryData.trackData[selectIndex].url!
            secondVc.nowLyricText = displayMusicLibraryData.trackData[selectIndex].lyric
            secondVc.editPlayNum = selectIndex
            secondVc.editShffuleFromTypeFlg = false
            secondVc.editLibraryName = self.title!
            selectIndex = 0
        }
    }
    deinit {
        if nowBarBtn == 1 {
            // DB保存
            let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
            let context:NSManagedObjectContext = appDelegate.managedObjectContext
            let fetchRequest:NSFetchRequest<MusicModel> = MusicModel.fetchRequest()
            let predicate = NSPredicate(format:"%K = %@","musicLibraryName",self.title!)
            fetchRequest.predicate = predicate
            let fetchData = try! context.fetch(fetchRequest)
            // 並び替え後のデータを保存
            if(!fetchData.isEmpty){
                for i in 0..<displayMusicLibraryData.trackData.count{
                    fetchData[i].indicatoryNum = Int16(i)
                    fetchData[i].albumTitle = displayMusicLibraryData.trackData[i].albumName
                    fetchData[i].artist = displayMusicLibraryData.trackData[i].artist
                    if displayMusicLibraryData.trackData[i].artworkImg == nil {
                        fetchData[i].artworkData = nil
                    } else{
                        fetchData[i].artworkData = displayMusicLibraryData.trackData[i].artworkImg!.pngData()! as NSData as Data
                    }
                    fetchData[i].lyric = displayMusicLibraryData.trackData[i].lyric
                    fetchData[i].musicLibraryName = self.musicLibraryName
                    fetchData[i].trackTitle = displayMusicLibraryData.trackData[i].title
                    fetchData[i].url = String(describing: displayMusicLibraryData.trackData[i].url!)

                }
                do{
                    try context.save()
                }catch{
                    dlog(error)
                }
                
            }
        }
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        let center = NotificationCenter.default
        
        // AVAudio Session
        center.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        center.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
}
