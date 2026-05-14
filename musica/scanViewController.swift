//
//  scanViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2018/04/22.
//  Copyright © 2018年 K.T. All rights reserved.
//
import UIKit
import CoreData
import GoogleMobileAds
import Alamofire
import Instructions
import SwiftyJSON
import BubbleTransition
import Reachability
import Firebase
import AVFoundation
import Speech

class scanViewController: UIViewController ,CoachMarksControllerDataSource, CoachMarksControllerDelegate, UIImagePickerControllerDelegate,UINavigationControllerDelegate,FullScreenContentDelegate,FADDelegate{
    
    @IBOutlet weak var langwaitView: UIView!
    @IBOutlet weak var helpBtn: UIBarButtonItem!
    @IBOutlet weak var coachMarkLangView: UIView!
    @IBOutlet weak var coachMarkTransView: UIView!
    @IBOutlet weak var clearOrShareBtn: UIButton!
    @IBOutlet weak var resetBtn: UIButton!
    @IBOutlet weak var controlView: UIView!
    @IBOutlet weak var waitView: UIVisualEffectView!
    @IBOutlet weak var previewImage: UIImageView!
    @IBOutlet weak var nowimageBtn: UIButton!
    @IBOutlet weak var previewImageView: UIVisualEffectView!
    @IBOutlet weak var langSelectBtn: UIButton!
    @IBOutlet weak var registerBtn: UIButton!
    @IBOutlet weak var imageListBtn: UIButton!
    @IBOutlet weak var scrollResultView: UIScrollView!
    @IBOutlet weak var modeSelectBtn: UIButton!
    @IBOutlet weak var resultTextView: UITextView!
    @IBOutlet weak var cameraBtn: UIButton!
    @IBOutlet weak var clearBtn: UIBarButtonItem!
    @IBOutlet weak var transSegment: UISegmentedControl!
    var textViewSize = CGRect()

    // MARK: - 音声文字起こしボタン
    private let micBtn  = UIButton(type: .system)   // WhisperKit（waveform / xmark.circle.fill）
    private let sfBtn   = UIButton(type: .system)   // SFSpeech / ライブマイク（mic.fill）
    private let transcribeProgressLabel = UILabel() // SFSpeech ライブ録音用
    private var whisperTask: Task<Void, Never>?
    private var whisperIsRunning = false

    private var whisperOverlay: TranscriptionLoadingOverlay?
    private var cancelSFTranscription: (() -> Void)?
    // ライブマイク録音
    private let audioEngine = AVAudioEngine()
    private var liveRecognitionTasks: [SFSpeechRecognitionTask] = []
    private var liveRecognitionRequests: [SFSpeechAudioBufferRecognitionRequest] = []
    private var liveRestartTimer: Timer?
    private var isLiveRecording = false
    private var liveTranscribedText = ""
    private var liveAccumulatedText = ""

    // Layout — frame-based keyboard avoidance
    private var keyboardOffset: CGFloat = 0
    private var isKeyboardVisible = false

    // Design — programmatic header card
    private var statusCard: UIView?
    private var statusIconView: UIImageView?
    private var statusTitleLabel: UILabel?
    private var statusSubtitleLabel: UILabel?
    private var statusCopyBtn: UIButton?

    var ADMOB_REWARD_RECEIVED = false
    var FROM_TRAND_AD = false
    let transition = BubbleTransition()
    var textAreaEditHeihgt: CGFloat = 0   // kept for legacy paths
    var color = AppColor.inactive
    var toLangCode = Int()
    let jsonEncoder = JSONEncoder()
    var interstitial: InterstitialAd?
    var interstitial_five : FADInterstitial!
    var transSuccessFlg = false
    
    /*
     オフライン検知
     */
    let reachability = try! Reachability()
    
    /*
     チュートリアル
     */
    @IBOutlet weak var coachMarkScanView: UIView!
    let coachMarksController = CoachMarksController()
    let ALL_HELP = 0
    let SCAN_HELP = 1
    let TRANS_HELP = 2
    var HELPMODE = 0
    
    // 歌詞の登録
    var EDIT_FLG = false
    var editLibraryName = ""
    var editTrackUrl : URL! = nil
    var nowLyricText = ""
    var editPlayNum = 0
    var editShffuleFromTypeFlg = true
    
    // 翻訳周り
    var LATEST_RESULT_TEXT = ""
    var LATEST_LYRIC_RESULT_TEXT = ""
    var TRANS_NOW_LANG = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Maio.setAdTestMode disabled - use mediation
        // Maio.start disabled - use mediation
        
        waitView.isHidden = true
        helpBtn.image = UIImage(systemName: "questionmark.circle.fill")
        helpBtn.tintColor = AppColor.accent
        helpBtn.isEnabled = true
        langSelectBtn.layer.borderColor = AppColor.textSecondary.cgColor
        clearOrShareBtn.layer.borderColor = AppColor.textSecondary.cgColor
        registerBtn.layer.borderColor = AppColor.textSecondary.cgColor
        resetBtn.layer.borderColor = AppColor.textSecondary.cgColor
        // チュートリアル
        self.coachMarksController.dataSource = self
        coachMarksController.overlay.blurEffectStyle = UIBlurEffect.Style(rawValue: 2) // ボカシ具合
        coachMarksController.overlay.isUserInteractionEnabled = true
        switch Int(myAppFrameSize.height) {
        case IPHONE_5_HEIGHT:
            textAreaEditHeihgt = 360
        case IPHONE_6_HEIGHT:
            textAreaEditHeihgt = 460
        case IPHONE_6PLUS_HEIGHT:
            textAreaEditHeihgt = 520
        case IPHONEX_HEIGHT:
            textAreaEditHeihgt = 550
        case IPHONEXSMAX_HEIGHT:
            textAreaEditHeihgt = 630
        default:
            textAreaEditHeihgt = scrollResultView.frame.size.height
        }
        // キーボードの「閉じる」ボタン作成
        let kbToolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 40))
        kbToolBar.barStyle = UIBarStyle.default  // スタイルを設定
        kbToolBar.sizeToFit()  // 画面幅に合わせてサイズを変更
        // スペーサー
        let spacer = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: self, action: nil)
        // 閉じるボタン
        let commitButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.done, target: self, action: #selector(scanViewController.editCloseBtnTapped))
        kbToolBar.items = [spacer, commitButton]
        resultTextView.inputAccessoryView = kbToolBar
        helpBtn.isEnabled = true
        // 初回表示前にナビゲーションバースタイルを確定（タブ切り替えチラつき防止）
        applySharedNavBarStyle()
        setupTranscribeButtons()
        redesignLayout()
    }
    /*******************************************************************
     画面描画時の処理
     *******************************************************************/
    override func viewWillAppear(_ animated: Bool) {
        // ナビゲーションバースタイルを super より先に確定してチラつきを防ぐ
        applySharedNavBarStyle()
        super.viewWillAppear(animated)
        // 動画は一旦止める
        if AVPlayerViewControllerManager.shared.controller.player != nil {
            AVPlayerViewControllerManager.shared.controller.player?.pause()
        }
        selectMusicView.isHidden = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.keyboardWillBeShown(notification:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.keyboardWillBeHiddenNotif),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        // 広告の準備
        setupFiveSDK()
        InterstitialAd.load(with: ADMOB_INTERSTITIAL_SCAN_OR_TRANS, request: Request()) { [weak self] ad, error in
                if let error = error { dlog("Error: \(error)"); return }
                self?.interstitial = ad
                self?.interstitial?.fullScreenContentDelegate = self
            }
        interstitial_five = FADInterstitial(slotId: "252628")
        interstitial_five?.delegate = self
        if (interstitial_five?.state != kFADStateLoaded) {
            FADSettings.enableLoading(true)// interstitialの生成と表示
            interstitial_five?.loadAd()
        }

        // 翻訳が成功し、広告から帰ってきた場合
        if transSuccessFlg {
            transSuccessFlg = false
            transSegment.selectedSegmentIndex = AFTER_TRANS
        }
        // editTrackUrl がなければ確実にスキャンモードに戻す（EDIT_FLG が残留するケース対策）
        if editTrackUrl == nil { EDIT_FLG = false }
        // タブ切り替えで来た場合でも、再生中 or 選択中の曲があれば micBtn を活性化する
        if editTrackUrl == nil, NowPlayingMusicLibraryData.nowPlaying != NOW_NOT_PLAYING {
            let tracks = SHUFFLE_FLG
                ? NowPlayingMusicLibraryData.trackDataShuffled
                : NowPlayingMusicLibraryData.trackData
            let idx = NowPlayingMusicLibraryData.nowPlaying
            if idx < tracks.count { editTrackUrl = tracks[idx].url }
        }
        updateStatusCard()
        updateTranscribeBtnState()
        if EDIT_FLG {
            registerBtn.isHidden = false
            registerBtn.isEnabled = true
            registerBtn.alpha = 1.0
            resetBtn.isHidden = true
            clearOrShareBtn.isHidden = true
            FROM_SCAN_CAMERA = false
            color = AppColor.destructive
            // 既存の歌詞をセット
            if LYRIC_RESULT_TEXT == ""{
                switch transSegment.selectedSegmentIndex {
                case BEFORE_TRANS:
                    resultTextView.text = nowLyricText
                case AFTER_TRANS:
                    resultTextView.text = LYRIC_TRANS_TEXT
                default:
                    resultTextView.text = nowLyricText
                }
            }else{
                switch transSegment.selectedSegmentIndex {
                case BEFORE_TRANS:
                    resultTextView.text = LYRIC_RESULT_TEXT
                case AFTER_TRANS:
                    resultTextView.text = LYRIC_TRANS_TEXT
                default:
                    resultTextView.text = LYRIC_RESULT_TEXT
                }
            }
            if previewImageLyricCaptured != nil {
                previewImage.contentMode = .scaleAspectFit
                previewImage.image = previewImageLyricCaptured
                nowimageBtn.setImage(previewImageLyricCaptured.withRenderingMode(UIImage.RenderingMode.alwaysOriginal), for: .normal)
                nowimageBtn.imageView?.contentMode = .scaleAspectFit
            }
            if CAMERAVIEW_LYRIC_RESULT_TEXT != ""{
                resultTextView.text = CAMERAVIEW_LYRIC_RESULT_TEXT
                CAMERAVIEW_LYRIC_RESULT_TEXT = ""
            }
        }else{
            // スキャンモード（非歌詞編集モード）
            clearOrShareBtn.isHidden = true
            registerBtn.isHidden = true
            resetBtn.isHidden = true
            FROM_SCAN_CAMERA = true
            color = AppColor.destructive
            self.navigationItem.title = localText(key:"trans_title")
            
            switch transSegment.selectedSegmentIndex {
            case BEFORE_TRANS:break
            case AFTER_TRANS:
                if TRANS_TEXT != ""{
                    resultTextView.text = TRANS_TEXT
                }
            default:break
            }
            if previewImageScanCaptured != nil {
                previewImage.contentMode = .scaleAspectFit
                previewImage.image = previewImageScanCaptured
                nowimageBtn.setImage(previewImageScanCaptured.withRenderingMode(UIImage.RenderingMode.alwaysOriginal), for: .normal)
                nowimageBtn.imageView?.contentMode = .scaleAspectFit
            }
            if CAMERAVIEW_RESULT_TEXT != ""{
                resultTextView.text = CAMERAVIEW_RESULT_TEXT
                CAMERAVIEW_RESULT_TEXT = ""
            }
        }
        
        if #available(iOS 10.0, *) {
            // iOS10以降の場合
            //cameraBtn.backgroundColor = UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)
        } else {
            // iOS9以前の場合
            cameraBtn.backgroundColor = AppColor.inactive
        }
        NotificationCenter.default.addObserver(self, selector: #selector(self.reachabilityChanged),name: ReachabilityChangedNotification,object: reachability)
        do{
            try reachability.startNotifier()
        }catch{
            dlog("could not start reachability notifier")
        }
        // オンラインだったら翻訳言語取得
        if reachability.isReachable {
            DispatchQueue.global(qos: .default).async {
                self.getLanguages()
                
            }
        }
        fadeInRanDomAnimesion(view : clearOrShareBtn)
        fadeInRanDomAnimesion(view : resetBtn)
        fadeInRanDomAnimesion(view : nowimageBtn)
        fadeInRanDomAnimesion(view : imageListBtn)
        fadeInRanDomAnimesion(view : cameraBtn)
        fadeInRanDomAnimesion(view : langSelectBtn)
        fadeInRanDomAnimesion(view : transSegment)
        self.langSelectBtn.setTitle(TRANS_LANG_SETTING.name, for: UIControl.State.normal)
        updateStatusCard()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    /*******************************************************************
     ボタンタップ時の処理
     *******************************************************************/
    @IBAction func helpBtnTapped(_ sender: Any) {
        helpBtn.isEnabled = false
        // キーボードを閉じる
        if isKeyboardVisible {
            resultTextView.resignFirstResponder()
        }
        helpBtn.isEnabled = true
        // アラートを作成
        let alert = UIAlertController(
            title: localText(key:"text_help_title"),
            message: localText(key:"text_help_body"),
            preferredStyle: .alert)
        // アラートにボタンをつける
        alert.addAction(UIAlertAction(title: localText(key:"text_help_nolook"), style: .cancel))
        alert.addAction(UIAlertAction(title: localText(key:"text_help_look"), style: .default, handler: { action in
            self.previewImageView.isHidden = true
            self.resultTextView.endEditing(true)
            self.HELPMODE = self.ALL_HELP
            self.coachMarksController.start(in: .newWindow(over: self, at: nil))
        }))
        alert.addAction(UIAlertAction(title: localText(key:"text_help_look_scan"), style: .default, handler: { action in
            self.previewImageView.isHidden = true
            self.resultTextView.endEditing(true)
            self.HELPMODE = self.SCAN_HELP
            self.coachMarksController.start(in: .newWindow(over: self, at: nil))
        }))
        alert.addAction(UIAlertAction(title: localText(key:"text_help_look_trans"), style: .default, handler: { action in
            self.previewImageView.isHidden = true
            self.resultTextView.endEditing(true)
            self.HELPMODE = self.TRANS_HELP
            self.coachMarksController.start(in: .newWindow(over: self, at: nil))
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    // クリア/シェアボタンタップ時
    @IBAction func clearOrShareBtnTapped(_ sender: Any) {
        // 歌詞編集モード時のみ「クリア」として動作（スキャンモードではボタン非表示のため通常到達しない）
        if EDIT_FLG {
            resultTextView.text = ""
            RESULT_TEXT = ""
            TRANS_TEXT = ""
        }
    }
    // 翻訳切り替え
    @IBAction func transSegmentTapped(_ sender: Any) {
        switch transSegment.selectedSegmentIndex {
        case BEFORE_TRANS:
            if  EDIT_FLG == false {
                TRANS_TEXT = resultTextView.text
                resultTextView.text = RESULT_TEXT
            } else{
                LYRIC_TRANS_TEXT = resultTextView.text
                resultTextView.text = LYRIC_RESULT_TEXT
            }
        case AFTER_TRANS:
            // ネットワークチェック
            if reachability.isReachable == false{
                self.transSegment.selectedSegmentIndex = BEFORE_TRANS
                let alertController = UIAlertController(title: localText(key:"err"),message: localText(key:"text_err_network"), preferredStyle: UIAlertController.Style.alert)
                // アラートにボタンをつける
                alertController.addAction(UIAlertAction(title: localText(key:"btn_ok"), style: .cancel))
                present(alertController, animated: true, completion: nil)
                return
            }
            if resultTextView.text.count == 0 {
                self.transSegment.selectedSegmentIndex = BEFORE_TRANS
                resultTextView.text = localText(key:"text_err_notextorigin")
                return
            }
            if TRANS_NOW_LANG != TRANS_LANG_SETTING.code {
                tlansText()
            }else{
                if EDIT_FLG == false  {
                    if LATEST_RESULT_TEXT != RESULT_TEXT {
                        tlansText()
                    }else{
                        RESULT_TEXT = resultTextView.text
                        resultTextView.text = TRANS_TEXT
                    }
                }else{
                    if LATEST_LYRIC_RESULT_TEXT != LYRIC_RESULT_TEXT {
                        tlansText()
                    }else{
                        LYRIC_RESULT_TEXT = resultTextView.text
                        resultTextView.text = LYRIC_TRANS_TEXT
                    }
                }
            }
        default: break;
        }
    }
    @IBAction func imageListBtnTapped(_ sender: Any) {
        tappedAnimation(tappedBtn: sender as! UIButton )
        if waitView.isHidden == false{
            return
        }
        // カメラロールが利用可能か？
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            imageListBtn.isEnabled = false
            // 写真を選ぶビュー
            let pickerView = UIImagePickerController()
            // 写真の選択元をカメラロールにする
            // 「.camera」にすればカメラを起動できる
            pickerView.sourceType = .photoLibrary
            // デリゲート
            pickerView.delegate = self as UIImagePickerControllerDelegate & UINavigationControllerDelegate
            // ビューに表示
            imageListBtn.isEnabled = false
            pickerView.modalPresentationStyle = .fullScreen
            self.present(pickerView, animated: true)
        }
    }
    // キャンセルされた時に呼ばれる
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
       // reloodFlg = true
        imageListBtn.isEnabled = true
        picker.dismiss(animated: true, completion: nil)
    }
    // 写真を選んだ後に呼ばれる処理
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        self.transSegment.selectedSegmentIndex = BEFORE_TRANS
        let image = info[.originalImage] as! UIImage
        nowimageBtn.setImage(image.withRenderingMode(UIImage.RenderingMode.alwaysOriginal), for: .normal)
        nowimageBtn.imageView?.contentMode = .scaleAspectFit
        
        previewImage.contentMode = .scaleAspectFit
        previewImage.image = image
        nowimageBtn.isEnabled = true
        imageListBtn.isEnabled = true
        // ネットワークチェック
        if reachability.isReachable == false{
            self.dismiss(animated: true)
            let alertController = UIAlertController(title: localText(key:"err"),message: localText(key:"text_err_network"), preferredStyle: UIAlertController.Style.alert)
            // アラートにボタンをつける
            alertController.addAction(UIAlertAction(title: localText(key:"btn_ok"), style: .cancel))
            present(alertController, animated: true, completion: nil)
            return
        }

        waitView.isHidden = false
        helpBtn.isEnabled = false
        detectTextGoogle(image: image)
        self.dismiss(animated: true)
        
        // UserDefaultsを使ってスキャン回数をカウントする
        //var scan_count = 0
        if UserDefaults.standard.object(forKey: "scanCount") == nil{
            UserDefaults.standard.set(SCAN_USE_NUM, forKey: "scanCount")
        }else{
            SCAN_USE_NUM = UserDefaults.standard.integer(forKey: "scanCount") + 1
            UserDefaults.standard.set(SCAN_USE_NUM, forKey: "scanCount")
        }
        Analytics.setUserProperty(String(SCAN_USE_NUM), forName: "スキャン回数")
        if SCAN_AD_INTERVAL != 0{
            if SCAN_USE_NUM % SCAN_AD_INTERVAL == 0{
                // 広告表示
                if let interstitial = interstitial {
                    interstitial.present(from: self)
                } else {
                    dlog("Admob wasn't ready")
                    // 初期化
                    let interstitial_five = FADInterstitial(slotId: "252628")
                    interstitial_five?.delegate = self
                    interstitial_five?.loadAd()
                    if (interstitial_five?.state == kFADStateLoaded) {
                        //self.view.addSubview(interstitial)
                        interstitial_five?.show()
                        UserDefaults.standard.set(SCAN_USE_NUM, forKey: "scanCount")
                    }
                }
            }
        }
    }
    //「閉じるボタン」で呼び出されるメソッド
    @objc func editCloseBtnTapped() {
        saveCurrentText()
        resultTextView.resignFirstResponder()
    }

    @objc func copyAllTextTapped() {
        let text = resultTextView.text ?? ""
        guard !text.isEmpty else {
            showToastMsg(messege: localText(key: "scan_copy_empty"), time: 1.5, tab: COLOR_THEMA.SEARCH.rawValue)
            return
        }
        UIPasteboard.general.string = text
        showToastMsg(messege: localText(key: "scan_copy_done"), time: 1.5, tab: COLOR_THEMA.SEARCH.rawValue)
    }
    // カメラボタンタップ時
    @IBAction func cameraBtnTapped(_ sender: Any) {
        tappedAnimation(tappedBtn: sender as! UIButton )
        let status = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        switch (status) {
        case .authorized:break
        case .restricted:
            showCamereAlert()
            return
        case .notDetermined:break
        case .denied:
            showCamereAlert()
            return
        }
        if  registerBtn.isHidden {
            RESULT_TEXT = ""
        }else{
            LYRIC_RESULT_TEXT = ""
        }
        self.transSegment.selectedSegmentIndex = BEFORE_TRANS
        // iOS10以降の場合
        let storyboard: UIStoryboard = self.storyboard!
        let nextView = storyboard.instantiateViewController(withIdentifier: "cameraView")
        nextView.transitioningDelegate = self
        nextView.modalPresentationStyle = .custom
        present(nextView, animated: true, completion: nil)
    }
    // リセットボタンタップ時
    @IBAction func resetBtnTapped(_ sender: Any) {
        resultTextView.text = nowLyricText
        LYRIC_TRANS_TEXT = ""
        LYRIC_RESULT_TEXT = ""
        LATEST_LYRIC_RESULT_TEXT = ""
    }
    // 翻訳言語選択ボタンタップ時
    @IBAction func selectLangBtnTapped(_ sender: Any) {
        setLang()
    }
    // 登録ボタンタップ時
    @IBAction func registerBtnTapped(_ sender: Any) {
        if EDIT_FLG {
            var msgBody = ""
            // アラートを作成
            let alert = UIAlertController(
                title: localText(key:"musiclibrary_lylic_regist_title"),
                message: resultTextView.text,
                preferredStyle: .alert)
            // アラートにボタンをつける
            let action1 = UIAlertAction(title: localText(key:"btn_ok"), style: UIAlertAction.Style.default, handler: {
                (action: UIAlertAction!) in
                // 更新処理へ進む
                let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
                let context:NSManagedObjectContext = appDelegate.managedObjectContext
                let fetchRequest:NSFetchRequest<MusicModel> = MusicModel.fetchRequest()
                let predicate = NSPredicate(format:"%K = %@","musicLibraryName",self.editLibraryName)
                fetchRequest.predicate = predicate
                let fetchData = try! context.fetch(fetchRequest)
                if(!fetchData.isEmpty){
//                    var trackTitle = ""
                    for i in 0..<fetchData.count{
                        if URL(string: fetchData[i].url!) == self.editTrackUrl! {
                            fetchData[i].lyric = self.resultTextView.text
//                            if self.editShffuleFromTypeFlg == false {
//                                trackTitle = displayMusicLibraryData.trackData[self.editPlayNum].title
//                            } else {
//                                if SHUFFLE_FLG{
//                                    trackTitle = NowPlayingMusicLibraryData.trackDataShuffled[self.editPlayNum].title
//                                }else{
//                                    dlog(self.editPlayNum)
//                                    trackTitle = NowPlayingMusicLibraryData.trackData[self.editPlayNum].title
//                                }
//                            }
                            break
                        }
                    }
                    // 更新内容を保存
                    do{
                        try context.save()
                        msgBody = localText(key:"musiclibrary_lylic_regist_success")
                        
                        if self.editShffuleFromTypeFlg == false {
                            // 音楽一覧画面からの遷移時
                            displayMusicLibraryData.trackData[self.editPlayNum].lyric = self.resultTextView.text
                            if displayMusicLibraryData.musicLibraryCode == NowPlayingMusicLibraryData.musicLibraryCode {
                                if SHUFFLE_FLG{
                                    var nowPlayS = 0
                                    for i in 0...NowPlayingMusicLibraryData.trackData.count - 1 {
                                        if NowPlayingMusicLibraryData.trackDataShuffled[self.editPlayNum].url == displayMusicLibraryData.trackData[i].url{
                                            nowPlayS = i
                                            break
                                        }
                                    }
                                    displayMusicLibraryData.trackData[nowPlayS].lyric = self.resultTextView.text
                                    displayMusicLibraryData.trackDataShuffled[self.editPlayNum].lyric = self.resultTextView.text
                                    NowPlayingMusicLibraryData.trackData[nowPlayS].lyric  = self.resultTextView.text
                                    NowPlayingMusicLibraryData.trackDataShuffled[self.editPlayNum].lyric  = self.resultTextView.text
                                }else{
                                    var nowPlay = 0
                                    for i in 0...NowPlayingMusicLibraryData.trackDataShuffled.count - 1 {
                                        if displayMusicLibraryData.trackData[self.editPlayNum].url == NowPlayingMusicLibraryData.trackDataShuffled[i].url{
                                            nowPlay = i
                                            break
                                        }
                                    }
                                    displayMusicLibraryData.trackData[self.editPlayNum].lyric = self.resultTextView.text
                                    displayMusicLibraryData.trackDataShuffled[nowPlay].lyric = self.resultTextView.text
                                    NowPlayingMusicLibraryData.trackData[self.editPlayNum].lyric  = self.resultTextView.text
                                    NowPlayingMusicLibraryData.trackDataShuffled[nowPlay].lyric  = self.resultTextView.text
                                }
                            }
                        } else {
                            // 音楽再生画面からの遷移時
                            if SHUFFLE_FLG{
                                var nowPlayS = 0
                                for i in 0...NowPlayingMusicLibraryData.trackData.count - 1 {
                                    if NowPlayingMusicLibraryData.trackDataShuffled[self.editPlayNum].url == NowPlayingMusicLibraryData.trackData[i].url{
                                        nowPlayS = i
                                        break
                                    }
                                }
                                NowPlayingMusicLibraryData.trackData[nowPlayS].lyric = self.resultTextView.text
                                NowPlayingMusicLibraryData.trackDataShuffled[self.editPlayNum].lyric = self.resultTextView.text
                                if displayMusicLibraryData.musicLibraryCode == NowPlayingMusicLibraryData.musicLibraryCode {
                                    displayMusicLibraryData.trackDataShuffled[self.editPlayNum].lyric = self.resultTextView.text
                                    displayMusicLibraryData.trackData[nowPlayS].lyric = self.resultTextView.text
                                }
                            }else{
                                var nowPlay = 0
                                for i in 0...NowPlayingMusicLibraryData.trackDataShuffled.count - 1 {
                                    if NowPlayingMusicLibraryData.trackData[self.editPlayNum].url == NowPlayingMusicLibraryData.trackDataShuffled[i].url{
                                        nowPlay = i
                                        break
                                    }
                                }
                                NowPlayingMusicLibraryData.trackData[self.editPlayNum].lyric = self.resultTextView.text
                                NowPlayingMusicLibraryData.trackDataShuffled[nowPlay].lyric = self.resultTextView.text
                                if displayMusicLibraryData.musicLibraryCode == NowPlayingMusicLibraryData.musicLibraryCode {
                                    displayMusicLibraryData.trackDataShuffled[nowPlay].lyric = self.resultTextView.text
                                    displayMusicLibraryData.trackData[self.editPlayNum].lyric = self.resultTextView.text
                                }
                            }
                        }
                    }catch{
                        dlog(error)
                        msgBody = localText(key:"musiclibrary_lylic_regist_failure")
                    }
                    showToastMsg(messege:msgBody,time:2.0, tab: COLOR_THEMA.SEARCH.rawValue)
                    self.EDIT_FLG = false
                    self.editTrackUrl = nil
                    self.navigationController?.popViewController(animated: true)
                    
//                    let resuleAlert = UIAlertController(
//                        title: msgTitle,
//                        message: msgBody,
//                        preferredStyle: .alert)
//                    // アラートにボタンをつける
//                    let okBtn = UIAlertAction(title: localText(key:"btn_ok"), style: UIAlertAction.Style.default, handler: {
//                        (action: UIAlertAction!) in
//                    })
//                    resuleAlert.addAction(okBtn)
                    // アラート表示
 //                   self.present(resuleAlert, animated: true, completion: nil)
                }
            })
            let action2 = UIAlertAction(title: MESSAGE_CANCEL, style: UIAlertAction.Style.default, handler: {
                (action: UIAlertAction!) in
                return
            })
            alert.addAction(action1)
            alert.addAction(action2)
            // アラート表示
            present(alert, animated: true, completion: nil)
        }
        // EDIT_FLG=false 時は registerBtn は非表示のため、ここには到達しない
    }
    // プレビューボタンタップ時
    @IBAction func nowImageBtnTapped(_ sender: Any) {
        tappedAnimation(tappedBtn: sender as! UIButton )
        if previewImageView.isHidden {
            previewImageView.isHidden = false
        }else{
            previewImageView.isHidden = true
        }
    }
    // プレビュー閉じるボタンタップ時
    @IBAction func previewCloseBtnTapped(_ sender: Any) {
        previewImageView.isHidden = true
    }
//    // チュートリアルの閉じるボタンタップ時
//    @IBAction func tutorialViewCloseBtnTApped(_ sender: Any) {
//        UserDefaults.standard.set(TRANS_REWARD_COUNT, forKey: "textTabTutorialFlg")
//        fadeoutAnimesion(view : tutorialView)
//        dialogPopDownAnimesion(view : totorialDialogView)
//        helpBtn.isEnabled = true
//    }
    /*******************************************************************
     翻訳の処理
     *******************************************************************/
    // 翻訳処理実行
    func tlansText(){
        if MAX_TEXT_NUM < 5 {
            MAX_TEXT_NUM = 10
        }
        if resultTextView.text.count > MAX_TEXT_NUM {
            let alertController = UIAlertController(title: localText(key:"text_err_textnum_title"),message: localText(key:"text_err_textnum_body1") + String(MAX_TEXT_NUM) + localText(key:"text_err_textnum_body2") + String(resultTextView.text.count) + localText(key:"text_err_textnum_body3"), preferredStyle: UIAlertController.Style.alert)
            let okAction = UIAlertAction(title: localText(key:"btn_ok"), style: UIAlertAction.Style.default){ (action: UIAlertAction) in
                self.transSegment.selectedSegmentIndex = BEFORE_TRANS
            }
            alertController.addAction(okAction)
            present(alertController,animated: true,completion: nil)
            waitView.isHidden = true
            helpBtn.isEnabled = true
            return
        }
        if resultTextView.text == "" {
            if  self.EDIT_FLG == false {
                TRANS_TEXT = localText(key:"text_err_notextorigin")
                resultTextView.text = RESULT_TEXT
            }else{
                LYRIC_TRANS_TEXT = localText(key:"text_err_notextorigin")
                resultTextView.text = LYRIC_RESULT_TEXT
            }
            waitView.isHidden = true
            helpBtn.isEnabled = true
            return
        }
        TRANS_REWARD_COUNT = TRANS_REWARD_COUNT - 1
        UserDefaults.standard.set(TRANS_REWARD_COUNT, forKey: "transCount")
        TRANS_USE_NUM = TRANS_USE_NUM + 1
        UserDefaults.standard.set(TRANS_USE_NUM, forKey: "trans_Count")
        Analytics.setUserProperty(String(TRANS_USE_NUM), forName: "翻訳回数")
        // 広告表示
        if TRANS_REWARD_COUNT < 1{
            self.transSegment.selectedSegmentIndex = BEFORE_TRANS
            if false { // Rewarded ad removed (GADRewardBasedVideoAd no longer available)
                // reward video was available here
            }else{
                if let interstitial = interstitial {
                    let alertController = UIAlertController(title: localText(key:"text_err_usecount_title"),message: localText(key:"text_err_usecount_body_tap"), preferredStyle: UIAlertController.Style.alert)
                    let okAction = UIAlertAction(title: localText(key:"btn_ok"), style: UIAlertAction.Style.default){ (action: UIAlertAction) in
                        interstitial.present(from: self)
                        self.FROM_TRAND_AD = true
                    }
                    let cancelButton = UIAlertAction(title: localText(key:"text_err_nolookad"), style: UIAlertAction.Style.default){ (action: UIAlertAction) in
                        self.waitView.isHidden = true
                        self.helpBtn.isEnabled = true
                        self.FROM_TRAND_AD = false
                        return
                    }
                    alertController.addAction(okAction)
                    alertController.addAction(cancelButton)
                    present(alertController,animated: true,completion: nil)
                }else{
                    if (interstitial_five?.state == kFADStateLoaded) {
                        let alertController = UIAlertController(title: localText(key:"text_err_usecount_title"),message: localText(key:"text_err_usecount_body_tap"), preferredStyle: UIAlertController.Style.alert)
                        let okAction = UIAlertAction(title: localText(key:"btn_ok"), style: UIAlertAction.Style.default){ (action: UIAlertAction) in
                            self.FROM_TRAND_AD = true
                            self.interstitial_five?.show()
                        }
                        let cancelButton = UIAlertAction(title: localText(key:"text_err_nolookad"), style: UIAlertAction.Style.default){ (action: UIAlertAction) in
                            self.waitView.isHidden = true
                            self.helpBtn.isEnabled = true
                            self.FROM_TRAND_AD = false
                            return
                        }
                        alertController.addAction(okAction)
                        alertController.addAction(cancelButton)
                        present(alertController,animated: true,completion: nil)
                    }else{
                        if false { // Maio direct API removed
                            let alertController = UIAlertController(title: localText(key:"text_err_usecount_title"),message: localText(key:"text_err_usecount_body"), preferredStyle: UIAlertController.Style.alert)
                            let okAction = UIAlertAction(title: localText(key:"btn_ok"), style: UIAlertAction.Style.default){ (action: UIAlertAction) in
                                // Maio.show removed
                            }
                            let cancelButton = UIAlertAction(title: localText(key:"text_err_nolookad"), style: UIAlertAction.Style.default){ (action: UIAlertAction) in
                                self.transSegment.selectedSegmentIndex = BEFORE_TRANS
                                return
                            }
                            alertController.addAction(okAction)
                            alertController.addAction(cancelButton)
                            present(alertController,animated: true,completion: nil)
                        }else{
                            waitView.isHidden = false
                            helpBtn.isEnabled = false
                            self.tlansLation()
                            self.transSegment.selectedSegmentIndex = AFTER_TRANS
                        }
                    }
                }
            }
        }else{
            waitView.isHidden = false
            helpBtn.isEnabled = false
            self.tlansLation()
            self.transSegment.selectedSegmentIndex = AFTER_TRANS
        }
    }
    // 翻訳対象言語取得
    func getLanguages() {
        // すでにget済みだったら何もしない
        if GET_LANG_FLG {
            DispatchQueue.main.async {
                self.langwaitView.isHidden = true
            }
            return
        }else{
            GET_LANG_FLG = true
        }
        if arrayLangInfo.count > 10 {
            DispatchQueue.main.async {
                self.langwaitView.isHidden = true
            }
            return
        }
        let sampleLangAddress = "https://dev.microsofttranslator.com/languages?api-version=3.0&scope=translation"
        let url1 = URL(string: sampleLangAddress)
        var jsonLangData = Data()
        do {
            jsonLangData = try Data(contentsOf: url1!)
        }catch{
            GET_LANG_FLG = false
            return
        }
        struct Translation: Codable {
            var translation: [String: LanguageDetails]
        }
        struct LanguageDetails: Codable {
            var name: String
            var nativeName: String
            var dir: String
        }
        
        let jsonDecoder1 = JSONDecoder()
        var languages: Translation?
        
        languages = try! jsonDecoder1.decode(Translation.self, from: jsonLangData)
        var eachLangInfo = AllLangDetails(code: " ", name: " ", nativeName: " ", dir: " ") //Use this instance to populate and then append to the array instance
        
        for languageValues in languages!.translation.values {
            eachLangInfo.name = languageValues.name
            eachLangInfo.nativeName = languageValues.nativeName
            eachLangInfo.dir = languageValues.dir
            arrayLangInfo.append(eachLangInfo)
        }
        
        let countOfLanguages = languages?.translation.count
        var counter = 0
        
        for languageKey in languages!.translation.keys {
            
            if counter < countOfLanguages! {
                arrayLangInfo[counter].code = languageKey
                counter += 1
            }
        }
        arrayLangInfo.sort(by: {$0.nativeName > $1.nativeName}) //sort the structs based on the language name
        DispatchQueue.main.async {
            self.langwaitView.isHidden = true
        }
    }
    // 言語設定
    func setLang(){
        let actionSheet = UIAlertController(title: localText(key:"text_selectlang_title"), message: localText(key:"text_selectlang_body"), preferredStyle:UIAlertController.Style.actionSheet)
        
        var style = UIAlertAction.Style.default
        for i in 0 ..< arrayLangInfo.count {
            if TRANS_LANG_SETTING.code == arrayLangInfo[i].code{
                style = UIAlertAction.Style.destructive
            }else{
                style = UIAlertAction.Style.default
            }
            let action = UIAlertAction(title: arrayLangInfo[i].name, style: style, handler: {
            (action: UIAlertAction!) in
                if TRANS_LANG_SETTING.code == arrayLangInfo[i].code{
                    //self.transSegment.selectedSegmentIndex = AFTER_TRANS
                    if  self.EDIT_FLG == false {
                        TRANS_TEXT = self.resultTextView.text
                        self.resultTextView.text = TRANS_TEXT
                    }else{
                        LYRIC_TRANS_TEXT = self.resultTextView.text
                        self.resultTextView.text = LYRIC_TRANS_TEXT
                    }
                }else{
                    self.transSegment.selectedSegmentIndex = BEFORE_TRANS
                    if  self.EDIT_FLG == false {
                        if RESULT_TEXT != ""{
                            self.resultTextView.text = RESULT_TEXT
                        }
                    }else{
                        if LYRIC_RESULT_TEXT != ""{
                            self.resultTextView.text = LYRIC_RESULT_TEXT
                        }
                    }
                }
                
                TRANS_LANG_SETTING = arrayLangInfo[i]
                self.langSelectBtn.setTitle(arrayLangInfo[i].name, for: UIControl.State.normal)
            })
            actionSheet.addAction(action)
        }
        let cancel = UIAlertAction(title: localText(key:"btn_cancel"), style: UIAlertAction.Style.cancel, handler: {
            (action: UIAlertAction!) in
            dlog("キャンセルをタップした時の処理")
        })
        actionSheet.addAction(cancel)
        
        self.present(actionSheet, animated: true, completion: nil)
        
    }
    
    // 翻訳実行
    func tlansLation(){
        TRANS_NOW_LANG = TRANS_LANG_SETTING.code
        
        struct encodeText: Codable {
            var text = String()
        }
        let azureKey = "845926f490b64129911ae9f79333aa87"
        let contentType = "application/json"
        let traceID = "A14C9DB9-0DED-48D7-8BBE-C517A1A8DBB0"
        let host = "dev.microsofttranslator.com"
        let apiURL = "https://dev.microsofttranslator.com/translate?api-version=3.0&to=" + TRANS_NOW_LANG
        
        let text2Translate = resultTextView.text
        var encodeTextSingle = encodeText()
        var toTranslate = [encodeText]()
        
        encodeTextSingle.text = text2Translate!
        toTranslate.append(encodeTextSingle)
        let jsonToTranslate = try? jsonEncoder.encode(toTranslate) //ここで落ちる
        let url = URL(string: apiURL)
        if url == nil {
            DispatchQueue.main.async {
                self.waitView.isHidden = true
                self.helpBtn.isEnabled = true
                self.resultTextView.text = localText(key:"text_err_trans_failure")
                self.transSegment.selectedSegmentIndex = BEFORE_TRANS
            }
            return
        }
        var request = URLRequest(url: url!)
        
        request.httpMethod = "POST"
        request.addValue(azureKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        request.addValue(traceID, forHTTPHeaderField: "X-ClientTraceID")
        request.addValue(host, forHTTPHeaderField: "Host")
        request.addValue(String(describing: jsonToTranslate?.count), forHTTPHeaderField: "Content-Length")
        request.httpBody = jsonToTranslate
        
        let config = URLSessionConfiguration.default
        let session =  URLSession(configuration: config)
        let task = session.dataTask(with: request) { (responseData, response, responseError) in
            if responseError != nil || responseData == nil {
                DispatchQueue.main.async {
                    self.waitView.isHidden = true
                    self.helpBtn.isEnabled = true
                    self.transSegment.selectedSegmentIndex = BEFORE_TRANS
                    showAlertMsgOneOkBtn(title: TEXT_ERR_DIALOG_TITLE,messege: TEXT_ERR_DIALOG_BODY)
                }
                return
            }
            self.parseJson(jsonData: responseData!)
        }
        task.resume()
    }
    
    // JSON パース
    func parseJson(jsonData: Data) {
        
        //*****TRANSLATION RETURNED DATA*****
        struct ReturnedJson: Codable {
            var translations: [TranslatedStrings]
        }
        struct TranslatedStrings: Codable {
            var text: String
            var to: String
        }
        
        let jsonDecoder = JSONDecoder()
        let langTranslations = try? jsonDecoder.decode(Array<ReturnedJson>.self, from: jsonData)
        if langTranslations == nil{
            //Put response on main thread to update UI
            DispatchQueue.main.async {
                self.resultTextView.text = localText(key:"text_err_trans_failure")
            }
            waitView.isHidden = true
            helpBtn.isEnabled = true
            return
        }
        let numberOfTranslations = langTranslations!.count - 1
        dlog(langTranslations!.count)
        
        //Put response on main thread to update UI
        DispatchQueue.main.async {
            // 翻訳時のTEXTを保存
            if  self.EDIT_FLG == false {
                self.LATEST_RESULT_TEXT = RESULT_TEXT
                RESULT_TEXT = self.resultTextView.text // kore
                TRANS_TEXT = langTranslations![0].translations[numberOfTranslations].text
                self.resultTextView.text = TRANS_TEXT
            }else{
                self.LATEST_LYRIC_RESULT_TEXT = LYRIC_RESULT_TEXT
                LYRIC_RESULT_TEXT = self.resultTextView.text // kore
                LYRIC_TRANS_TEXT = langTranslations![0].translations[numberOfTranslations].text
                self.resultTextView.text = LYRIC_TRANS_TEXT
            }
            
            self.waitView.isHidden = true
            self.helpBtn.isEnabled = true
            self.transSuccessFlg = true
        }
    }
    /*******************************************************************
     Google Cloud Vision API関連の処理
     *******************************************************************/
    // APIに画像を渡して解析
    func detectTextGoogle(image : UIImage) {
        // 画像はbase64する
        if let base64image = image.pngData()?.base64EncodedString() {
            // リクエストの作成
            // 文字検出をしたいのでtypeにはTEXT_DETECTIONを指定する
            // 画像サイズの制限があるので本当は大きすぎたらリサイズしたりする必要がある
            let request: Parameters = [
                "requests": [
                    "image": [
                        "content": base64image
                    ],
                    "features": [
                        [
                            "type": "TEXT_DETECTION",
                            "maxResults": 1
                        ]
                    ]
                ]
            ]
            // Google Cloud PlatformのAPI Managerでキーを制限している場合、リクエストヘッダのX-Ios-Bundle-Identifierに指定した値を入れる
            let httpHeader: HTTPHeaders = [
                "Content-Type": "application/json",
                "X-Ios-Bundle-Identifier": Bundle.main.bundleIdentifier ?? ""
            ]
            // googleApiKeyにGoogle Cloud PlatformのAPI Managerで取得したAPIキーを入れる
            AF.request("https://vision.googleapis.com/v1/images:annotate?key=\(GOOGLE_VISION_API)", method: .post, parameters: request, encoding: JSONEncoding.default, headers: httpHeader).validate(statusCode: 200..<300).responseJSON { response in
                // レスポンスの処理
                googleResult(response: response)
            }
        }
        // 解析結果の取得
        func googleResult(response: AFDataResponse<Any>) {
            guard let result = response.value else {
                // アラートを作成
                let alert = UIAlertController(
                    title: localText(key:"text_err_failure"),
                    message: localText(key:"text_err_scan_failure_body"),
                    preferredStyle: .alert)
                // アラートにボタンをつける
                let action1 = UIAlertAction(title: MESSAGE_CANCEL, style: UIAlertAction.Style.default, handler: {
                    (action: UIAlertAction!) in
                    self.waitView.isHidden = true
                    self.helpBtn.isEnabled = true
                    self.imageListBtn.isEnabled = true
                    self.resultTextView.text = localText(key:"text_err_scan_failure_title")
                    self.dismiss(animated: true, completion: nil)
                })
                alert.addAction(action1)
                // アラート表示
                present(alert, animated: true, completion: nil)
                return
            }
            let json = JSON(result)
            let annotations: JSON = json["responses"][0]["textAnnotations"]
            var detectedText: String = ""
            // 結果からdescriptionを取り出して一つの文字列にする
            annotations.forEach { (_, annotation) in
                detectedText += annotation["description"].string!
            }
            let splitDetectedText = detectedText.components(separatedBy: "\n")
            var resultDetectedText = ""
            if splitDetectedText.count > 0 {
                if splitDetectedText.count == 1 && splitDetectedText[0] == "" {
                    resultDetectedText = localText(key:"text_err_scan_nochara")
                }else{
                    let resultIndex = splitDetectedText[splitDetectedText.count - 1].count + (splitDetectedText.count - 1)
                    resultDetectedText = String(detectedText[detectedText.startIndex...detectedText.index(detectedText.startIndex, offsetBy: resultIndex)])
                }
            }else{
                resultDetectedText = localText(key:"text_err_scan_nochara")
            }
            // 結果を表示する
            if EDIT_FLG == false {//FROM_SCAN_CAMERA {
                RESULT_TEXT = resultDetectedText
                FROM_SCAN_CAMERA = false
                waitView.isHidden = true
                helpBtn.isEnabled = true
                resultTextView.text = RESULT_TEXT
            }else{
                LYRIC_RESULT_TEXT = resultDetectedText
                FROM_SCAN_CAMERA = false
                waitView.isHidden = true
                helpBtn.isEnabled = true
                imageListBtn.isEnabled = true
                resultTextView.text = LYRIC_RESULT_TEXT
            }
        }
    }
    /*******************************************************************
     テキスト編集周りの処理
     *******************************************************************/
    /// テキストを現在のセグメントに合わせて保存する（キーボード非表示時に呼ぶ）
    private func saveCurrentText() {
        switch transSegment.selectedSegmentIndex {
        case BEFORE_TRANS:
            if self.registerBtn.isHidden {
                RESULT_TEXT = resultTextView.text
            } else {
                LYRIC_RESULT_TEXT = resultTextView.text
            }
        case AFTER_TRANS:
            if self.registerBtn.isHidden {
                TRANS_TEXT = resultTextView.text
            } else {
                LYRIC_TRANS_TEXT = resultTextView.text
            }
        default: break
        }
    }

    /// キーボード非表示（IBActionから直接呼ばれるパス）
    func keyboardWillBeHidden() {
        saveCurrentText()
        // constraint animation は keyboardWillHide notification で行う
        resultTextView.resignFirstResponder()
    }

    @objc private func keyboardWillBeHiddenNotif() {
        saveCurrentText()
        isKeyboardVisible = false
        keyboardOffset = 0
        UIView.animate(withDuration: 0.25) {
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
    }

    // キーボード表示
    @objc func keyboardWillBeShown(notification: NSNotification) {
        guard let rect = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        isKeyboardVisible = true
        // キーボード分だけコントロールパネルを上げる（セーフエリア分は layoutViews 内で吸収済み）
        keyboardOffset = rect.height - view.safeAreaInsets.bottom
        UIView.animate(withDuration: duration) {
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
    }
    /*******************************************************************
     HELPの処理
     *******************************************************************/
    func numberOfCoachMarks(for coachMarksController: CoachMarksController) -> Int {
        switch HELPMODE {
        case ALL_HELP:
            return 7
        case SCAN_HELP:
            return 5
        case TRANS_HELP:
            return 3
        default:
            return 7
        }
    }
    func coachMarksController(_ coachMarksController: CoachMarksController,
                              coachMarkAt index: Int) -> CoachMark {
        var help_index = index
        switch HELPMODE {
        case ALL_HELP:
            help_index = index
        case SCAN_HELP:
            help_index = index
        case TRANS_HELP:
            help_index = index + 4
        default:
            help_index = index
        }
        switch help_index {
        case 0:
            return coachMarksController.helper.makeCoachMark(for: coachMarkScanView)
        case 1:
            let coachMark = coachMarksController.helper.makeCoachMark(for: imageListBtn) {
                (frame: CGRect) -> UIBezierPath in
                return UIBezierPath(ovalIn: frame.insetBy(dx: -5,dy: -5))
            }
            return coachMark
        case 2:
            let coachMark = coachMarksController.helper.makeCoachMark(for: cameraBtn) {
                (frame: CGRect) -> UIBezierPath in
                return UIBezierPath(ovalIn: frame.insetBy(dx: -5,dy: -5))
            }
            return coachMark
        case 3:
            return coachMarksController.helper.makeCoachMark(for: nowimageBtn)
        case 4:
            return coachMarksController.helper.makeCoachMark(for: resultTextView)
        case 5:
            return coachMarksController.helper.makeCoachMark(for: coachMarkTransView)
        case 6:
            return coachMarksController.helper.makeCoachMark(for: coachMarkLangView)

        default:
            return coachMarksController.helper.makeCoachMark(for: langSelectBtn)
        }
    }
        
    func coachMarksController(_ coachMarksController: CoachMarksController, coachMarkViewsAt index: Int, madeFrom coachMark: CoachMark) -> (bodyView: (UIView & CoachMarkBodyView), arrowView: (UIView & CoachMarkArrowView)?) {
        
        let coachViews = coachMarksController.helper.makeDefaultCoachViews(withArrow: true, arrowOrientation: coachMark.arrowOrientation)

        var help_index = index
        switch HELPMODE {
        case ALL_HELP:
            help_index = index
        case SCAN_HELP:
            help_index = index
        case TRANS_HELP:
            help_index = index + 4
        default:
            help_index = index
        }
        switch help_index {
        case 0:
            coachViews.bodyView.hintLabel.text = localText(key:"text_help_1")
            coachViews.bodyView.nextLabel.text = localText(key:"btn_ok")
        case 1:
            coachViews.bodyView.hintLabel.text = localText(key:"text_help_2")
            coachViews.bodyView.nextLabel.text = localText(key:"btn_ok")
        case 2:
            coachViews.bodyView.hintLabel.text = localText(key:"text_help_3")
            coachViews.bodyView.nextLabel.text = localText(key:"btn_ok")
        case 3:
            coachViews.bodyView.hintLabel.text = localText(key:"text_help_4")
            coachViews.bodyView.nextLabel.text = localText(key:"btn_ok")
        case 4:
            switch HELPMODE {
            case ALL_HELP:
                coachViews.bodyView.hintLabel.text = localText(key:"text_help_5")
            case SCAN_HELP:
                coachViews.bodyView.hintLabel.text = localText(key:"text_help_6")
            case TRANS_HELP:
                coachViews.bodyView.hintLabel.text = localText(key:"text_help_7")
            default:
                coachViews.bodyView.hintLabel.text = localText(key:"text_help_8")
            }
            coachViews.bodyView.nextLabel.text = localText(key:"btn_ok")
        case 5:
            switch HELPMODE {
            case ALL_HELP:
                coachViews.bodyView.hintLabel.text = localText(key:"text_help_9")
            case SCAN_HELP:
                coachViews.bodyView.hintLabel.text = localText(key:"text_help_10")
            case TRANS_HELP:
                coachViews.bodyView.hintLabel.text = localText(key:"text_help_11")
            default:
                coachViews.bodyView.hintLabel.text = localText(key:"text_help_12")
            }
            coachViews.bodyView.nextLabel.text = localText(key:"btn_ok")
        case 6:
            coachViews.bodyView.hintLabel.text = localText(key:"text_help_13")
            coachViews.bodyView.nextLabel.text = localText(key:"btn_ok")
        default:
            coachViews.bodyView.hintLabel.text = localText(key:"text_help_14")
            coachViews.bodyView.nextLabel.text = localText(key:"btn_ok")
        }
        
        coachViews.bodyView.nextLabel.textColor = AppColor.accent
        
        return (bodyView: coachViews.bodyView, arrowView: coachViews.arrowView)
    }
    
    /*******************************************************************
     広告（Admob と Five）の処理
     *******************************************************************/
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd){
        if self.FROM_TRAND_AD {
            ADMOB_REWARD_RECEIVED = true
            TRANS_REWARD_COUNT = TRANS_REWARD_COUNT + 3//Int(reward.amount)
            if TRANS_REWARD_COUNT < -5 {
                TRANS_REWARD_COUNT = -5
            }
            UserDefaults.standard.set(TRANS_REWARD_COUNT, forKey: "transCount")
            self.transSegment.selectedSegmentIndex = AFTER_TRANS
            self.waitView.isHidden = false
            self.helpBtn.isEnabled = false
            self.FROM_TRAND_AD = false
            self.tlansLation()
        }
    }
    
    // FIVE
    func fiveAdDidLoad(_ ad: FADAdInterface!) {}
    func fiveAdDidReplay(_ ad: FADAdInterface!) {}
    func fiveAdDidViewThrough(_ ad: FADAdInterface!) {}
    func fiveAdDidResume(_ ad: FADAdInterface!) {}
    func fiveAdDidPause(_ ad: FADAdInterface!) {}
    func fiveAdDidStart(_ ad: FADAdInterface!) {}
    func fiveAdDidClose(_ ad: FADAdInterface!) {
        if (interstitial_five?.state != kFADStateLoaded) {
            interstitial_five = FADInterstitial(slotId: "252628")
            interstitial_five?.delegate = self
            FADSettings.enableLoading(true)// interstitialの生成と表示
            interstitial_five?.loadAd()
        }
        dlog(FADAdInterface.self)
    }
    func fiveAdDidClick(_ ad: FADAdInterface!) {
        // ここで報酬ゲット
        if self.FROM_TRAND_AD {
            TRANS_REWARD_COUNT = TRANS_REWARD_COUNT + TRAN_AD_INTERVAL
            if TRANS_REWARD_COUNT < -5 {
                TRANS_REWARD_COUNT = -5
            }
            UserDefaults.standard.set(TRANS_REWARD_COUNT, forKey: "transCount")
            self.transSegment.selectedSegmentIndex = AFTER_TRANS
            self.waitView.isHidden = false
            self.helpBtn.isEnabled = false
            self.FROM_TRAND_AD = false
            self.tlansLation()
        }
    }
    func fiveAd(_ ad: FADAdInterface!, didFailedToReceiveAdWithError errorCode: FADErrorCode) {
        dlog(errorCode)
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
            DispatchQueue.global(qos: .default).async {
                self.getLanguages()
            }
        } else {
            dlog("Network not reachable")
        }
    }
    /*******************************************************************
     画面遷移時の処理
     *******************************************************************/
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        //editShffuleFromTypeFlg = true
        //イベントリスナーの削除
        NotificationCenter.default.removeObserver(self)
        self.coachMarksController.stop(immediately: true)
        // 音声認識停止
        if isLiveRecording { stopLiveMicRecording() }
        whisperTask?.cancel()
        cancelSFTranscription?()
    }
    // オブジェクト破棄時に監視を解除
    deinit {
        //イベントリスナーの削除
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Redesign

    /// 他タブと同じ glassmorphism ナビゲーションバースタイルを適用
    /// configureWithTransparentBackground() は Blur レンダリング遅延で背後の黒が透けるため使わない。
    /// configureWithOpaqueBackground() + 半透明ベース色 + backgroundEffect で同等の見た目を実現。
    private func applySharedNavBarStyle() {
        // navigationController.view の背景を app 背景色で塗り、透明 nav bar 越しの「黒透け」を防ぐ
        navigationController?.view.backgroundColor = AppColor.background

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppColor.background.withAlphaComponent(0.85)
        appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        appearance.shadowColor = .clear          // セパレータ線を非表示
        appearance.titleTextAttributes = [.foregroundColor: AppColor.textPrimary]
        navigationController?.navigationBar.standardAppearance   = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance    = appearance
        navigationController?.navigationBar.tintColor            = AppColor.accent
    }

    private func redesignLayout() {
        view.backgroundColor = AppColor.background
        navigationItem.largeTitleDisplayMode = .never

        // ── テキストエリア（スクロール中カード）────────────────────────
        resultTextView.backgroundColor     = AppColor.surface
        resultTextView.textColor           = AppColor.textPrimary
        resultTextView.font                = UIFont.systemFont(ofSize: 16, weight: .regular)
        resultTextView.layer.cornerRadius  = 0   // scrollView 側でクリップ
        resultTextView.layer.masksToBounds = false
        resultTextView.layer.borderWidth   = 0
        resultTextView.textContainerInset  = UIEdgeInsets(top: 16, left: 14, bottom: 16, right: 14)
        resultTextView.keyboardDismissMode = .interactive

        scrollResultView.backgroundColor   = AppColor.surface
        scrollResultView.layer.cornerRadius = 16
        scrollResultView.layer.masksToBounds = true
        scrollResultView.layer.shadowColor  = AppColor.shadow.cgColor
        scrollResultView.layer.shadowOpacity = 1.0
        scrollResultView.layer.shadowRadius  = 8
        scrollResultView.layer.shadowOffset  = CGSize(width: 0, height: 2)
        scrollResultView.layer.masksToBounds = false

        // ── コントロールパネル ────────────────────────────────────────
        controlView.backgroundColor    = AppColor.surface
        controlView.layer.cornerRadius = 20
        controlView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        controlView.layer.masksToBounds = false
        controlView.layer.shadowColor   = AppColor.shadow.cgColor
        controlView.layer.shadowOpacity = 1.0
        controlView.layer.shadowOffset  = CGSize(width: 0, height: -4)
        controlView.layer.shadowRadius  = 16

        // ── セグメント ────────────────────────────────────────────────
        transSegment.selectedSegmentTintColor = AppColor.accent
        transSegment.setTitleTextAttributes([.foregroundColor: AppColor.textPrimary,
                                             .font: UIFont.systemFont(ofSize: 13, weight: .medium)], for: .normal)
        transSegment.setTitleTextAttributes([.foregroundColor: UIColor.white,
                                             .font: UIFont.systemFont(ofSize: 13, weight: .semibold)], for: .selected)
        if #available(iOS 13, *) {
            transSegment.backgroundColor = AppColor.surfaceSecondary
        }

        // ── ボタン ────────────────────────────────────────────────────
        applyButtonStyle(cameraBtn,     filled: true,   tinted: false, symbol: "camera.fill")
        applyButtonStyle(imageListBtn,  filled: true,   tinted: false, symbol: "photo.on.rectangle")
        applyButtonStyle(langSelectBtn, filled: false,  tinted: false, symbol: "globe")

        // クリア・戻す・登録: アイコン上＋ラベル下の縦積みレイアウト
        applyIconLabelBtn(clearOrShareBtn, symbol: "xmark",                 label: localText(key: "scan_btn_clear"),    filled: false, tinted: true)
        applyIconLabelBtn(resetBtn,        symbol: "arrow.counterclockwise", label: localText(key: "scan_btn_undo"),     filled: false, tinted: true)
        applyIconLabelBtn(registerBtn,     symbol: "checkmark",              label: localText(key: "scan_btn_register"), filled: true,  tinted: false)

        // nowimageBtn: サムネイル風（枠線 + 角丸）
        nowimageBtn.layer.cornerRadius  = 10
        nowimageBtn.layer.masksToBounds = true
        nowimageBtn.layer.borderWidth   = 1.5
        nowimageBtn.layer.borderColor   = AppColor.textSecondary.withAlphaComponent(0.3).cgColor
        nowimageBtn.backgroundColor     = AppColor.surfaceSecondary
        nowimageBtn.imageView?.contentMode = .scaleAspectFill

        // langSelectBtn: ちゃんと枠線付きチップに
        langSelectBtn.layer.cornerRadius  = 10
        langSelectBtn.layer.masksToBounds = true
        langSelectBtn.layer.borderWidth   = 1.5
        langSelectBtn.layer.borderColor   = AppColor.accent.withAlphaComponent(0.4).cgColor

        // ── コンテナから引き剥がして controlView 直下に再配置 ──────────
        // storyboard では langSelectBtn/transSegment/各ボタンが別コンテナの
        // 中にネストされているため、フレーム管理するには直下に移す必要がある。
        let toReparent: [UIView] = [
            langSelectBtn, transSegment,
            cameraBtn, imageListBtn, nowimageBtn,
            clearOrShareBtn, resetBtn, registerBtn
        ]
        for v in toReparent {
            if v.superview !== controlView {
                v.removeFromSuperview()
                controlView.addSubview(v)
            }
            v.translatesAutoresizingMaskIntoConstraints = true
        }

        // 空になったコンテナ・装飾ビューは非表示
        coachMarkLangView.isHidden  = true
        coachMarkTransView.isHidden = true
        coachMarkScanView.isHidden  = true

        // controlView の制約を全解除
        controlView.constraints.forEach { controlView.removeConstraint($0) }
        for sv in controlView.subviews {
            sv.translatesAutoresizingMaskIntoConstraints = true
        }

        // セパレーターライン（初回のみ追加）
        if controlView.viewWithTag(9901) == nil {
            let sep = UIView()
            sep.tag = 9901
            sep.backgroundColor = AppColor.textSecondary.withAlphaComponent(0.15)
            sep.translatesAutoresizingMaskIntoConstraints = true
            controlView.addSubview(sep)
        }

        // ── ヘッダーカードを構築 ──────────────────────────────────────
        buildStatusCard()

        // ── ストーリーボード制約を除去 → フレーム管理に切替 ────────────
        for v in [scrollResultView!, controlView!] as [UIView] {
            v.superview?.constraints
                .filter { $0.firstItem === v || $0.secondItem === v }
                .forEach { v.superview?.removeConstraint($0) }
            v.translatesAutoresizingMaskIntoConstraints = true
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        layoutViews()
    }

    private func layoutViews() {
        let W = view.bounds.width
        let H = view.bounds.height
        guard W > 0 else { return }

        let safeTop    = view.safeAreaInsets.top
        let safeBottom = view.safeAreaInsets.bottom
        let pad: CGFloat = 12
        let gap: CGFloat = 8
        let statusH: CGFloat = 66
        // コントロールパネル: 2行分 + セパレーター + 上下パディング + safeBottom
        let cvInner: CGFloat = 14 + 36 + 9 + 1 + 9 + 46 + 14
        let cvH: CGFloat = cvInner + safeBottom

        // 1. ステータスカード
        statusCard?.frame = CGRect(x: pad,
                                   y: safeTop + gap,
                                   width: W - pad * 2,
                                   height: statusH)

        // 2. コントロールパネル（キーボードで上昇）
        let cvY = H - keyboardOffset - cvH
        controlView.frame = CGRect(x: 0, y: cvY, width: W, height: cvH)

        // 3. テキストエリア（ステータスカード下〜コントロール上）
        let textY = safeTop + gap + statusH + gap
        let textH = max(cvY - gap - textY, 60)
        scrollResultView.frame = CGRect(x: pad, y: textY,
                                        width: W - pad * 2, height: textH)

        // 4. コントロールパネル内部レイアウト
        layoutControlSubviews()
    }

    private func layoutControlSubviews() {
        let W = controlView.bounds.width
        guard W > 0 else { return }

        let hPad: CGFloat  = 16
        let vPad: CGFloat  = 14
        let row1H: CGFloat = 36   // 言語＋セグメント行
        let row2H: CGFloat = 46   // アクションボタン行
        let sepH:  CGFloat = 1
        let gap:   CGFloat = 9
        let btnGap: CGFloat = 8
        let innerW = W - hPad * 2

        // ── Row 1: 言語 (42%) | 翻訳セグメント (58%) ─────────────────
        // コンテナを経由せず直接 controlView 上に配置
        let y1    = vPad
        let langW = innerW * 0.42
        let segW  = innerW - langW - btnGap

        langSelectBtn.frame = CGRect(x: hPad,                   y: y1, width: langW, height: row1H)
        transSegment.frame  = CGRect(x: hPad + langW + btnGap,  y: y1, width: segW,  height: row1H)

        // ── セパレーター ──────────────────────────────────────────────
        let sepY = y1 + row1H + gap
        controlView.viewWithTag(9901)?.frame = CGRect(x: hPad, y: sepY, width: innerW, height: sepH)

        // ── Row 2: ボタン行 ───────────────────────────────────────────
        let y2    = sepY + sepH + gap
        let btnW: CGFloat = 48

        // 左グループ: [📷] [📸] [🖼サムネ]
        imageListBtn.frame = CGRect(x: hPad,                       y: y2, width: btnW, height: row2H)
        cameraBtn.frame    = CGRect(x: hPad + btnW + btnGap,       y: y2, width: btnW, height: row2H)
        nowimageBtn.frame  = CGRect(x: hPad + (btnW + btnGap) * 2, y: y2, width: btnW, height: row2H)

        // 右グループ: [クリア] [戻す] [登録]
        // isHidden で表示を切り替えるが、位置は常に固定（条件分岐なし）
        let regW:   CGFloat = 64
        let smBtnW: CGFloat = 48
        let rightEdge = W - hPad

        // 右端: 登録ボタン
        registerBtn.frame = CGRect(x: rightEdge - regW,
                                    y: y2, width: regW, height: row2H)
        // 登録の左: リセットボタン
        resetBtn.frame = CGRect(x: rightEdge - regW - btnGap - smBtnW,
                                 y: y2, width: smBtnW, height: row2H)
        // リセットの左: クリアボタン
        clearOrShareBtn.frame = CGRect(x: rightEdge - regW - btnGap - smBtnW - btnGap - smBtnW,
                                        y: y2, width: smBtnW, height: row2H)
    }

    // MARK: ステータスカード（練習タブのヘッダーカードと同じ構造）

    private func buildStatusCard() {
        let card = UIView()
        card.backgroundColor    = AppColor.surface
        card.layer.cornerRadius = 16
        card.layer.masksToBounds = false
        card.layer.shadowColor   = AppColor.shadow.cgColor
        card.layer.shadowOpacity = 1.0
        card.layer.shadowRadius  = 8
        card.layer.shadowOffset  = CGSize(width: 0, height: 2)
        // frame は layoutViews() で管理するので TAMIC = true（デフォルト）
        view.addSubview(card)
        statusCard = card

        // アクセントバー（左端）
        let accent = UIView()
        accent.backgroundColor    = AppColor.accent
        accent.layer.cornerRadius = 2
        accent.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(accent)

        // アイコン
        let icon = UIImageView()
        icon.tintColor = AppColor.accent
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(icon)
        statusIconView = icon

        // タイトル
        let title = UILabel()
        title.font      = UIFont.systemFont(ofSize: 15, weight: .semibold)
        title.textColor = AppColor.textPrimary
        title.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(title)
        statusTitleLabel = title

        // サブタイトル
        let sub = UILabel()
        sub.font      = UIFont.systemFont(ofSize: 12, weight: .regular)
        sub.textColor = AppColor.textSecondary
        sub.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(sub)
        statusSubtitleLabel = sub

        // 全コピーボタン（右端）
        let copyBtn = UIButton(type: .system)
        let copyCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        copyBtn.setImage(UIImage(systemName: "doc.on.doc", withConfiguration: copyCfg), for: .normal)
        copyBtn.tintColor = AppColor.textSecondary
        copyBtn.addTarget(self, action: #selector(copyAllTextTapped), for: .touchUpInside)
        copyBtn.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(copyBtn)
        statusCopyBtn = copyBtn

        NSLayoutConstraint.activate([
            // アクセントバー
            accent.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            accent.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            accent.widthAnchor.constraint(equalToConstant: 4),
            accent.heightAnchor.constraint(equalToConstant: 28),

            // アイコン
            icon.leadingAnchor.constraint(equalTo: accent.trailingAnchor, constant: 12),
            icon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28),

            // 全コピーボタン（右端）
            copyBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            copyBtn.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            copyBtn.widthAnchor.constraint(equalToConstant: 36),
            copyBtn.heightAnchor.constraint(equalToConstant: 44),

            // タイトル
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            title.topAnchor.constraint(equalTo: card.topAnchor, constant: 13),
            title.trailingAnchor.constraint(lessThanOrEqualTo: copyBtn.leadingAnchor, constant: -8),

            // サブタイトル
            sub.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            sub.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
            sub.trailingAnchor.constraint(lessThanOrEqualTo: copyBtn.leadingAnchor, constant: -8),
            sub.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -13),
        ])
    }

    private func updateStatusCard() {
        let symConf = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        if EDIT_FLG {
            statusIconView?.image = UIImage(systemName: "music.note.list", withConfiguration: symConf)
            // 編集対象の曲名・アーティストを表示
            let tracks = displayMusicLibraryData.trackData
            if editPlayNum < tracks.count {
                let track = tracks[editPlayNum]
                statusTitleLabel?.text    = track.title.isEmpty ? localText(key: "scan_unknown_title") : track.title
                statusSubtitleLabel?.text = track.artist.isEmpty ? editLibraryName : "\(track.artist)  —  \(editLibraryName)"
            } else {
                statusTitleLabel?.text    = localText(key: "scan_edit_mode")
                statusSubtitleLabel?.text = editLibraryName
            }
            // コピーボタンを有効化
            statusCopyBtn?.isHidden = false  // 曲選択済みはコピーボタン表示
        } else {
            statusIconView?.image    = UIImage(systemName: "doc.text.viewfinder", withConfiguration: symConf)
            statusTitleLabel?.text   = localText(key: "scan_status_title")
            statusSubtitleLabel?.text = localText(key: "scan_status_sub")
            statusCopyBtn?.isHidden = true
        }
    }

    // MARK: - 音声文字起こしボタン セットアップ

    private func setupTranscribeButtons() {
        micBtn.addTarget(self, action: #selector(micBtnTapped), for: .touchUpInside)
        sfBtn.addTarget(self, action: #selector(sfBtnTapped), for: .touchUpInside)

        let micBarBtn = UIBarButtonItem(customView: micBtn)
        let sfBarBtn  = UIBarButtonItem(customView: sfBtn)
        // rightBarButtonItems: index 0 = 右端 → helpBtn を右端に保持
        navigationItem.rightBarButtonItems = [helpBtn, sfBarBtn, micBarBtn]

        updateTranscribeBtnState()

        // ── SFSpeech ライブ録音用ラベル (controlView 直上) ──────────────
        transcribeProgressLabel.font = UIFont.systemFont(ofSize: 12)
        transcribeProgressLabel.textColor = .white
        transcribeProgressLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        transcribeProgressLabel.layer.cornerRadius = 8
        transcribeProgressLabel.clipsToBounds = true
        transcribeProgressLabel.numberOfLines = 2
        transcribeProgressLabel.textAlignment = .center
        transcribeProgressLabel.isHidden = true
        transcribeProgressLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(transcribeProgressLabel)
        view.bringSubviewToFront(transcribeProgressLabel)
        NSLayoutConstraint.activate([
            transcribeProgressLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            transcribeProgressLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            transcribeProgressLabel.bottomAnchor.constraint(equalTo: controlView.topAnchor, constant: -8),
            transcribeProgressLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
        ])

        // WhisperKit 文字起こしオーバーレイ
        let overlay = TranscriptionLoadingOverlay()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.alpha    = 0
        overlay.isHidden = true
        overlay.cancelAction = { [weak self] in self?.cancelWhisperTapped() }
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        whisperOverlay = overlay
    }

    private func updateTranscribeBtnState() {
        if isLiveRecording {
            configureTranscribeBtn(sfBtn,  icon: "stop.circle.fill", color: .systemRed,   enabled: true)
            configureTranscribeBtn(micBtn, icon: "waveform",          color: .systemGray,  enabled: false)
        } else if editTrackUrl != nil {
            configureTranscribeBtn(micBtn, icon: "waveform",  color: AppColor.accent,  enabled: true)
            configureTranscribeBtn(sfBtn,  icon: "mic.fill",  color: .systemGreen,     enabled: true)
        } else {
            configureTranscribeBtn(micBtn, icon: "waveform",  color: .systemGray,      enabled: false)
            configureTranscribeBtn(sfBtn,  icon: "mic.fill",  color: .systemGreen,     enabled: true)
        }
    }

    private func configureTranscribeBtn(_ btn: UIButton, icon: String, color: UIColor, enabled: Bool) {
        var cfg = UIButton.Configuration.plain()
        cfg.image = UIImage(systemName: icon,
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
        cfg.baseForegroundColor = color
        btn.configuration = cfg
        btn.isEnabled = enabled
        btn.alpha = enabled ? 1.0 : 0.35
    }

    // MARK: - WhisperKit オーバーレイ表示制御

    private func showWhisperBanner() {
        if let overlay = whisperOverlay { view.bringSubviewToFront(overlay) }
        whisperOverlay?.show()
        configureTranscribeBtn(micBtn, icon: "xmark.circle.fill", color: .systemRed, enabled: true)
        sfBtn.isEnabled = false; sfBtn.alpha = 0.35
    }

    private func hideWhisperBanner() {
        whisperOverlay?.hide()
        updateTranscribeBtnState()
        sfBtn.isEnabled = true; sfBtn.alpha = 1
    }

    @objc private func cancelWhisperTapped() {
        whisperTask?.cancel()
        whisperTask = nil
        whisperIsRunning = false
        hideWhisperBanner()
    }

    // MARK: - WhisperKit ボタン

    @objc private func micBtnTapped() {
        // 実行中ならキャンセル
        if whisperIsRunning {
            cancelWhisperTapped()
            return
        }
        guard let url = editTrackUrl else {
            showTranscribeAlert(title: localText(key: "scan_no_music_title"),
                                message: localText(key: "scan_no_music_body"))
            return
        }
        if #available(iOS 16, *) {
            // Small モデル・言語全自動で即開始
            startWhisperTranscription(url: url, modelName: "openai_whisper-small", languages: [])
        } else {
            showTranscribeAlert(title: localText(key: "scan_unsupported_title"), message: localText(key: "scan_unsupported_body"))
        }
    }

    @available(iOS 16, *)
    private func startWhisperTranscription(url: URL, modelName: String, languages: [String]) {
        whisperTask?.cancel()
        whisperIsRunning = true
        showWhisperBanner()
        AVPlayerViewControllerManager.shared.controller.player?.pause()

        whisperTask = Task { [weak self] in
            guard let self else { return }
            do {
                let text = try await WhisperKitService.shared.transcribe(
                    url: url, modelName: modelName, languages: languages,
                    onProgress: { msg in
                        Task { @MainActor in self.whisperOverlay?.update(step: msg) }
                    }
                )
                await MainActor.run {
                    self.whisperIsRunning = false
                    self.hideWhisperBanner()
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.showTranscribeAlert(title: localText(key: "scan_no_result_title"), message: localText(key: "scan_no_result_body"))
                    } else {
                        self.applyTranscribeResult(text)
                    }
                }
            } catch {
                await MainActor.run {
                    self.whisperIsRunning = false
                    self.hideWhisperBanner()
                    if !(error is CancellationError) {
                        self.showTranscribeAlert(title: localText(key: "scan_error_title"), message: error.localizedDescription)
                    }
                }
            }
        }
    }

    // MARK: - SFSpeech ボタン

    @objc private func sfBtnTapped() {
        if isLiveRecording { stopLiveMicRecording(); return }
        if let url = editTrackUrl {
            showSFSpeechLanguagePicker(url: url)
        } else {
            showLiveMicLanguagePicker()
        }
    }

    private func showSFSpeechLanguagePicker(url: URL) {
        let sheet = UIAlertController(title: localText(key: "scan_lang_sf_title"), message: nil, preferredStyle: .actionSheet)
        for lang in TranscriptionService.languages {
            sheet.addAction(UIAlertAction(title: lang.label, style: .default) { [weak self] _ in
                self?.startSFSpeechTranscription(url: url, locales: lang.locales)
            })
        }
        sheet.addAction(UIAlertAction(title: localText(key: "btn_cancel"), style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = sfBtn; pop.sourceRect = sfBtn.bounds
        }
        present(sheet, animated: true)
    }

    private func startSFSpeechTranscription(url: URL, locales: [Locale]) {
        cancelSFTranscription?()
        setTranscribeLoading(true)
        AVPlayerViewControllerManager.shared.controller.player?.pause()

        cancelSFTranscription = TranscriptionService.transcribe(
            url: url, locales: locales,
            onChunkProgress: { [weak self] partial, chunk, total in
                self?.transcribeProgressLabel.text = "(\(chunk+1)/\(total)) \(partial.suffix(60))"
            },
            completion: { [weak self] result in
                guard let self else { return }
                self.setTranscribeLoading(false)
                switch result {
                case .success(let text):
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.showTranscribeAlert(title: localText(key: "scan_no_result_title"), message: localText(key: "scan_no_result_body"))
                    } else {
                        self.applyTranscribeResult(text)
                    }
                case .failure(let error):
                    self.showTranscribeAlert(title: localText(key: "scan_transcribe_fail_title"), message: error.localizedDescription)
                }
            }
        )
    }

    // MARK: - ライブマイク入力

    private func showLiveMicLanguagePicker() {
        // デバイスのロケールを取得し、対応する TranscriptionService の言語オプションを探す
        let deviceLocale = Locale.current
        let deviceLangName: String = {
            let code = deviceLocale.languageCode ?? deviceLocale.identifier
            return Locale.current.localizedString(forLanguageCode: code)
                ?? deviceLocale.localizedString(forLanguageCode: code)
                ?? code
        }()

        // デバイス言語に一致する TranscriptionService.LanguageOption を探す
        let deviceOption = TranscriptionService.languages.first {
            $0.locales.count == 1 &&
            $0.locales[0].languageCode == deviceLocale.languageCode
        }
        let deviceLocales = deviceOption?.locales ?? [deviceLocale]

        let sheet = UIAlertController(
            title: localText(key: "scan_lang_live_title"),
            message: localText(key: "scan_lang_live_msg"),
            preferredStyle: .actionSheet
        )

        // ── デバイスのデフォルト言語（先頭・チェック付き）──
        sheet.addAction(UIAlertAction(
            title: String(format: localText(key: "scan_lang_device_default_fmt"), deviceLangName),
            style: .default
        ) { [weak self] _ in
            self?.startLiveMicRecording(locales: deviceLocales)
        })

        // ── 自動判定モード ──
        let autoModes = TranscriptionService.languages.filter { $0.locales.count > 1 }
        if !autoModes.isEmpty {
            for lang in autoModes {
                sheet.addAction(UIAlertAction(title: lang.label, style: .default) { [weak self] _ in
                    self?.startLiveMicRecording(locales: lang.locales)
                })
            }
        }

        // ── 他の単一言語（デバイス言語と重複するものは除く）──
        let singleLangs = TranscriptionService.languages.filter {
            $0.locales.count == 1 &&
            $0.locales[0].languageCode != deviceLocale.languageCode
        }
        for lang in singleLangs {
            sheet.addAction(UIAlertAction(title: lang.label, style: .default) { [weak self] _ in
                self?.startLiveMicRecording(locales: lang.locales)
            })
        }

        sheet.addAction(UIAlertAction(title: localText(key: "btn_cancel"), style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = sfBtn; pop.sourceRect = sfBtn.bounds
        }
        present(sheet, animated: true)
    }

    private func startLiveMicRecording(locales: [Locale]) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    self?.showTranscribeAlert(title: localText(key: "scan_perm_error_title"),
                        message: localText(key: "scan_perm_speech_body"))
                    return
                }
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        if granted { self?.beginLiveRecording(locales: locales) }
                        else { self?.showTranscribeAlert(title: localText(key: "scan_perm_error_title"),
                            message: localText(key: "scan_perm_mic_body")) }
                    }
                }
            }
        }
    }

    /// 複数ロケールを並列認識しながら録音を開始。55s ごとに自動再起動して1分制限を回避。
    private func beginLiveRecording(locales: [Locale]) {
        let pairs: [(SFSpeechRecognizer, SFSpeechAudioBufferRecognitionRequest)] = locales.compactMap { locale in
            guard let r = SFSpeechRecognizer(locale: locale), r.isAvailable else { return nil }
            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            if #available(iOS 16, *) { req.addsPunctuation = true }
            return (r, req)
        }
        guard !pairs.isEmpty else {
            showTranscribeAlert(title: localText(key: "scan_error_title"), message: localText(key: "scan_no_engine_body"))
            return
        }
        do {
            AVPlayerViewControllerManager.shared.controller.player?.pause()
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            liveRecognitionRequests = pairs.map { $0.1 }
            let inputNode = audioEngine.inputNode
            let fmt = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buf, _ in
                self?.liveRecognitionRequests.forEach { $0.append(buf) }
            }
            audioEngine.prepare()
            try audioEngine.start()

            isLiveRecording  = true
            liveTranscribedText  = ""
            liveAccumulatedText  = ""
            updateTranscribeBtnState()
            transcribeProgressLabel.text    = localText(key: "scan_recording_label")
            transcribeProgressLabel.isHidden = false
            view.bringSubviewToFront(transcribeProgressLabel)

            liveRecognitionTasks = pairs.map { (recognizer, req) in
                recognizer.recognitionTask(with: req) { [weak self] result, _ in
                    guard let self, let result else { return }
                    let text = result.bestTranscription.formattedString
                    if text.count > self.liveTranscribedText.count { self.liveTranscribedText = text }
                    DispatchQueue.main.async {
                        let full = self.liveAccumulatedText.isEmpty
                            ? self.liveTranscribedText
                            : self.liveAccumulatedText + "\n" + self.liveTranscribedText
                        self.transcribeProgressLabel.text = "🎙 \(full.suffix(50))"
                    }
                }
            }
            scheduleLiveRestartTimer(locales: locales)
        } catch {
            isLiveRecording = false
            showTranscribeAlert(title: "録音エラー", message: error.localizedDescription)
        }
    }

    /// 55s ごとに認識タスクを再起動して iOS の1分制限を回避
    private func scheduleLiveRestartTimer(locales: [Locale]) {
        liveRestartTimer?.invalidate()
        liveRestartTimer = Timer.scheduledTimer(withTimeInterval: 55, repeats: false) { [weak self] _ in
            guard let self, self.isLiveRecording else { return }
            self.restartLiveRecording(locales: locales)
        }
    }

    private func restartLiveRecording(locales: [Locale]) {
        // 今セグメントのテキストを累積
        let seg = liveTranscribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !seg.isEmpty {
            liveAccumulatedText += (liveAccumulatedText.isEmpty ? "" : "\n") + seg
        }
        liveTranscribedText = ""

        // 旧タスク停止
        liveRecognitionRequests.forEach { $0.endAudio() }
        liveRecognitionTasks.forEach    { $0.finish() }
        liveRecognitionRequests = []
        liveRecognitionTasks    = []
        audioEngine.inputNode.removeTap(onBus: 0)

        // 新リクエスト作成
        let pairs: [(SFSpeechRecognizer, SFSpeechAudioBufferRecognitionRequest)] = locales.compactMap { locale in
            guard let r = SFSpeechRecognizer(locale: locale), r.isAvailable else { return nil }
            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            if #available(iOS 16, *) { req.addsPunctuation = true }
            return (r, req)
        }
        guard !pairs.isEmpty else { stopLiveMicRecording(); return }

        liveRecognitionRequests = pairs.map { $0.1 }
        let inputNode = audioEngine.inputNode
        let fmt = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buf, _ in
            self?.liveRecognitionRequests.forEach { $0.append(buf) }
        }
        liveRecognitionTasks = pairs.map { (recognizer, req) in
            recognizer.recognitionTask(with: req) { [weak self] result, _ in
                guard let self, let result else { return }
                let text = result.bestTranscription.formattedString
                if text.count > self.liveTranscribedText.count { self.liveTranscribedText = text }
                DispatchQueue.main.async {
                    let full = self.liveAccumulatedText.isEmpty
                        ? self.liveTranscribedText
                        : self.liveAccumulatedText + "\n" + self.liveTranscribedText
                    self.transcribeProgressLabel.text = "🎙 \(full.suffix(50))"
                }
            }
        }
        scheduleLiveRestartTimer(locales: locales)
    }

    private func stopLiveMicRecording() {
        liveRestartTimer?.invalidate()
        liveRestartTimer = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        liveRecognitionRequests.forEach { $0.endAudio() }
        liveRecognitionTasks.forEach    { $0.finish() }
        liveRecognitionRequests = []
        liveRecognitionTasks    = []
        isLiveRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        updateTranscribeBtnState()
        transcribeProgressLabel.isHidden = true

        let seg = liveTranscribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let acc = liveAccumulatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = acc.isEmpty ? seg : (seg.isEmpty ? acc : acc + "\n" + seg)
        liveTranscribedText  = ""
        liveAccumulatedText  = ""

        if combined.isEmpty {
            showTranscribeAlert(title: "結果なし", message: "音声を認識できませんでした。")
        } else {
            applyTranscribeResult(combined)
        }
    }

    // MARK: - 共通ヘルパー

    // SFSpeech（ファイル文字起こし）専用ローディング状態
    private func setTranscribeLoading(_ loading: Bool) {
        if loading {
            micBtn.isEnabled = false; micBtn.alpha = 0.35
            sfBtn.isEnabled  = false; sfBtn.alpha  = 0.35
            transcribeProgressLabel.text    = localText(key: "scan_transcribing")
            transcribeProgressLabel.isHidden = false
            view.bringSubviewToFront(transcribeProgressLabel)
        } else {
            updateTranscribeBtnState()
            transcribeProgressLabel.isHidden = true
        }
    }

    private func applyTranscribeResult(_ text: String) {
        let preview = String(text.prefix(200)) + (text.count > 200 ? "…" : "")
        let alert = UIAlertController(
            title: localText(key: "scan_transcribe_complete_title"),
            message: String(format: localText(key: "scan_transcribe_apply_body"), preview),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: localText(key: "scan_transcribe_apply_btn"), style: .default) { [weak self] _ in
            self?.resultTextView.text = text
            self?.LATEST_RESULT_TEXT = text
            LYRIC_RESULT_TEXT = text
        })
        alert.addAction(UIAlertAction(title: localText(key: "btn_cancel"), style: .cancel))
        present(alert, animated: true)
    }

    private func showTranscribeAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: localText(key: "btn_ok"), style: .default))
        present(alert, animated: true)
    }

    /// アイコン上 ＋ ラベル下 の縦積みボタン（クリア・戻す・登録など用）
    private func applyIconLabelBtn(_ btn: UIButton?, symbol: String, label: String, filled: Bool, tinted: Bool = false) {
        guard let btn else { return }
        if #available(iOS 15.0, *) {
            var cfg = tinted ? UIButton.Configuration.tinted() : (filled ? UIButton.Configuration.filled() : UIButton.Configuration.plain())
            let symCfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            cfg.image          = UIImage(systemName: symbol, withConfiguration: symCfg)
            cfg.imagePlacement = .top
            cfg.imagePadding   = 3
            cfg.title          = label
            cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
                var a = attrs
                a.font = UIFont.systemFont(ofSize: 9, weight: .medium)
                return a
            }
            if !tinted && !filled {
                cfg.background.backgroundColor = AppColor.surfaceSecondary
                cfg.background.cornerRadius    = 10
                cfg.baseForegroundColor        = AppColor.textPrimary
            } else if !tinted {
                cfg.background.cornerRadius = 10
            } else {
                cfg.background.cornerRadius = 10
            }
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 4, bottom: 5, trailing: 4)
            btn.configuration = cfg
            if tinted || filled { btn.tintColor = AppColor.accent }
        } else {
            btn.layer.cornerRadius = 10
            btn.layer.masksToBounds = true
            let fg: UIColor = filled ? .white : AppColor.accent
            btn.backgroundColor = filled ? AppColor.accent : AppColor.accent.withAlphaComponent(0.12)
            btn.setTitleColor(fg, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 10, weight: .medium)
            let symCfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            btn.setImage(UIImage(systemName: symbol, withConfiguration: symCfg), for: .normal)
            btn.tintColor = fg
            btn.setTitle(label, for: .normal)
        }
    }

    private func applyButtonStyle(_ btn: UIButton?, filled: Bool, tinted: Bool = false, symbol: String?) {
        guard let btn = btn else { return }

        if #available(iOS 15.0, *) {
            var config = tinted ? UIButton.Configuration.tinted() : (filled ? UIButton.Configuration.filled() : UIButton.Configuration.plain())
            if !tinted && !filled {
                config.background.backgroundColor = AppColor.surfaceSecondary
            }
            config.background.cornerRadius = 10
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
                var a = attrs
                a.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
                return a
            }
            if let sym = symbol {
                config.image = UIImage(systemName: sym,
                                       withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold))
                config.imagePadding   = 4
                config.imagePlacement = .leading
            }
            btn.configuration = config
            if tinted || filled { btn.tintColor = AppColor.accent }
            btn.titleLabel?.numberOfLines = 1
            btn.titleLabel?.adjustsFontSizeToFitWidth = true
            btn.titleLabel?.minimumScaleFactor = 0.7
        } else {
            btn.layer.cornerRadius  = 10
            btn.layer.masksToBounds = true
            btn.layer.borderWidth   = 0
            btn.titleLabel?.font    = UIFont.systemFont(ofSize: 14, weight: .semibold)
            let bg: UIColor = filled ? AppColor.accent : (tinted ? AppColor.accent.withAlphaComponent(0.12) : AppColor.surfaceSecondary)
            let fg: UIColor = filled ? .white : AppColor.accent
            btn.backgroundColor = bg
            btn.setTitleColor(fg, for: .normal)
            btn.tintColor = fg
            if let sym = symbol,
               let img = UIImage(systemName: sym,
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)) {
                btn.setImage(img, for: .normal)
                btn.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 6)
                btn.titleEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 0)
            }
        }
    }

}
extension scanViewController : UIViewControllerTransitioningDelegate{
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        transition.transitionMode = .present
        transition.startingPoint = CGPoint(x: myAppFrameSize.width / 2, y: myAppFrameSize.height - cameraBtn.center.y + (cameraBtn.frame.height / 4))
        transition.bubbleColor = AppColor.overlay
        return transition
    }
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        transition.transitionMode = .dismiss
        transition.startingPoint =  CGPoint(x:myAppFrameSize.width / 2 ,y:myAppFrameSize.height - cameraBtn.center.y + (cameraBtn.frame.height / 4))
        transition.bubbleColor = AppColor.overlay
        return transition
    }
    
}
