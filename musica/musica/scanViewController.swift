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
import ReachabilitySwift
import RAMAnimatedTabBarController
import Firebase

class scanViewController: UIViewController ,CoachMarksControllerDataSource, CoachMarksControllerDelegate, UIImagePickerControllerDelegate,UINavigationControllerDelegate,MaioDelegate,GADInterstitialDelegate,GADRewardBasedVideoAdDelegate,FADDelegate{
    
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
    
    var ADMOB_REWARD_RECEIVED = false
    var FROM_TRAND_AD = false
    let transition = BubbleTransition()
    var textAreaEditHeihgt:CGFloat = 0
    var color = UIColor.lightGray
    var toLangCode = Int()
    let jsonEncoder = JSONEncoder()
    var interstitial: GADInterstitial!
    var interstitial_five : FADInterstitial!
    var transSuccessFlg = false
    
    /*
     オフライン検知
     */
    let reachability = Reachability()!
    
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
        
        Maio.setAdTestMode(DEBUG_FLG)
        Maio.start(withMediaId: MAIO_APP_ID, delegate: self)
        
        waitView.isHidden = true
        helpBtn.isEnabled = true
        langSelectBtn.layer.borderColor = UIColor.darkGray.cgColor
        clearOrShareBtn.layer.borderColor = UIColor.darkGray.cgColor
        registerBtn.layer.borderColor = UIColor.darkGray.cgColor
        resetBtn.layer.borderColor = UIColor.darkGray.cgColor
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
        scrollResultView.frame.origin.y = 8 + (navigationController?.navigationBar.frame.size.height)! + UIApplication.shared.statusBarFrame.height

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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.keyboardWillBeShown(notification:)),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )
        // 広告の準備
        setupFiveSDK()
        interstitial = GADInterstitial(adUnitID: ADMOB_INTERSTITIAL_SCAN_OR_TRANS)
        interstitial_five = FADInterstitial(slotId: "252628")
        let request = GADRequest()
        interstitial.load(request)
        interstitial.delegate = self
        GADRewardBasedVideoAd.sharedInstance().delegate = self
        GADRewardBasedVideoAd.sharedInstance().load(GADRequest(),
                                                    withAdUnitID: ADMOB_REWARD_TRANS)
        interstitial_five?.delegate = self
        if (interstitial_five?.state != kFADStateLoaded) {
            FADSettings.enableLoading(true)// interstitialの生成と表示
            interstitial_five?.loadAd()
        }

        scrollResultView.translatesAutoresizingMaskIntoConstraints = false
        self.navigationController?.navigationBar.isTranslucent = false
        // 翻訳が成功し、広告から帰ってきた場合
        if transSuccessFlg {
            transSuccessFlg = false
            transSegment.selectedSegmentIndex = AFTER_TRANS
        }
        if EDIT_FLG {
            clearOrShareBtn.setTitle(localText(key:"trans_btn_clear"), for: UIControl.State.normal)
            registerBtn.setTitle(localText(key:"trans_btn_lyric_regist"), for: UIControl.State.normal)
            registerBtn.isHidden = false
            resetBtn.isHidden = false
            FROM_SCAN_CAMERA = false
            // navigationbarの設定
            self.navigationController?.navigationBar.barTintColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
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
            color = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
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
            clearOrShareBtn.setTitle(localText(key:"text_share"), for: UIControl.State.normal)
            if UserDefaults.standard.object(forKey: "scancamera_regist_cancel_flg") == nil{
                REGIST_CANCEL_FLG = false
                UserDefaults.standard.set(REGIST_CANCEL_FLG, forKey: "scancamera_regist_cancel_flg")
            }else{
                REGIST_CANCEL_FLG = UserDefaults.standard.bool(forKey: "scancamera_regist_cancel_flg")
            }
            if REGIST_CANCEL_FLG {
                registerBtn.isHidden = true
            }else{
                registerBtn.setTitle(localText(key:"text_moreuse"), for: UIControl.State.normal)
                registerBtn.isHidden = false
            }
            resetBtn.isHidden = true
            FROM_SCAN_CAMERA = true
            // navigationbarの色設定
            self.navigationController?.navigationBar.barTintColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SCAN.rawValue]
            //バーアイテムカラー
            if #available(iOS 15.0, *) {
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SCAN.rawValue]
                appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SCAN.rawValue]]
                self.navigationController!.navigationBar.standardAppearance = appearance
                self.navigationController!.navigationBar.scrollEdgeAppearance = self.navigationController!.navigationBar.standardAppearance
                self.navigationController!.navigationBar.tintColor = NAVIGATION_BTN_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SCAN.rawValue]
            } else {
                self.navigationController?.navigationBar.barTintColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SCAN.rawValue]
                self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SCAN.rawValue]]
                self.navigationController!.navigationBar.tintColor = NAVIGATION_BTN_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SCAN.rawValue]
            }
        
            color = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
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
            cameraBtn.backgroundColor = UIColor.lightGray
        }
        NotificationCenter.default.addObserver(self, selector: #selector(self.reachabilityChanged),name: ReachabilityChangedNotification,object: reachability)
        do{
            try reachability.startNotifier()
        }catch{
            print("could not start reachability notifier")
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
        fadeInRanDomAnimesion(view : registerBtn)
        fadeInRanDomAnimesion(view : imageListBtn)
        fadeInRanDomAnimesion(view : cameraBtn)
        self.langSelectBtn.setTitle(TRANS_LANG_SETTING.name, for: UIControl.State.normal)
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
        //キーボードを閉じる
        if self.scrollResultView.translatesAutoresizingMaskIntoConstraints {
            resultTextView.resignFirstResponder()
            keyboardWillBeHidden()
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
            if self.scrollResultView.translatesAutoresizingMaskIntoConstraints {
                self.resultTextView.endEditing(true)
                self.scrollResultView.translatesAutoresizingMaskIntoConstraints = false
                UIView.animate(withDuration: 0.1, animations: { () in
                    let frame = CGRect(x:self.scrollResultView.frame.origin.x, y:self.scrollResultView.frame.origin.y, width:self.scrollResultView.frame.width, height:CGFloat(self.textAreaEditHeihgt))
                    self.scrollResultView.frame = frame
                })
            }
            self.HELPMODE = self.ALL_HELP
            self.coachMarksController.start(in: .newWindow(over: self, at: nil))
        }))
        alert.addAction(UIAlertAction(title: localText(key:"text_help_look_scan"), style: .default, handler: { action in
            self.previewImageView.isHidden = true
            if self.scrollResultView.translatesAutoresizingMaskIntoConstraints {
                self.resultTextView.endEditing(true)
                self.scrollResultView.translatesAutoresizingMaskIntoConstraints = false
                UIView.animate(withDuration: 0.1, animations: { () in
                    let frame = CGRect(x:self.scrollResultView.frame.origin.x, y:self.scrollResultView.frame.origin.y, width:self.scrollResultView.frame.width, height:CGFloat(self.textAreaEditHeihgt))
                    self.scrollResultView.frame = frame
                })
            }
            self.HELPMODE = self.SCAN_HELP
            self.coachMarksController.start(in: .newWindow(over: self, at: nil))
        }))
        alert.addAction(UIAlertAction(title: localText(key:"text_help_look_trans"), style: .default, handler: { action in
            self.previewImageView.isHidden = true
            if self.scrollResultView.translatesAutoresizingMaskIntoConstraints {
                self.resultTextView.endEditing(true)
                self.scrollResultView.translatesAutoresizingMaskIntoConstraints = false
                UIView.animate(withDuration: 0.1, animations: { () in
                    let frame = CGRect(x:self.scrollResultView.frame.origin.x, y:self.scrollResultView.frame.origin.y, width:self.scrollResultView.frame.width, height:CGFloat(self.textAreaEditHeihgt))
                    self.scrollResultView.frame = frame
                })
            }
            self.HELPMODE = self.TRANS_HELP
            self.coachMarksController.start(in: .newWindow(over: self, at: nil))
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    // クリア/シェアボタンタップ時
    @IBAction func clearOrShareBtnTapped(_ sender: Any) {
        if EDIT_FLG {
            // クリアボタンタップ時
            resultTextView.text = ""
            RESULT_TEXT = ""
            TRANS_TEXT = ""
            
        }else{
            // シェアボタンタップ時
            let shareText = resultTextView.text
            let shareWebsite = NSURL(string: INTRODUCTION_URL)!
            let activityItems = [shareText!, shareWebsite] as [Any]
            
            // 初期化処理
            let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
            // UIActivityViewControllerを表示
            self.present(activityVC, animated: true, completion: nil)
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
                if interstitial.isReady {
                    interstitial.present(fromRootViewController: self)
                } else {
                    print("Admob wasn't ready")
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
        //キーボードを閉じる
        resultTextView.resignFirstResponder()
        keyboardWillBeHidden()
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
//                                    print(self.editPlayNum)
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
                        print(error)
                        msgBody = localText(key:"musiclibrary_lylic_regist_failure")
                    }
                    showToastMsg(messege:msgBody,time:2.0, tab: COLOR_THEMA.SEARCH.rawValue)
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
        }else{
            // アラートを作成
            let alert = UIAlertController(title: APP_INTRO_SCANCAMERA_TITLE,message: APP_INTRO_SCANCAMERA_BODY,preferredStyle: .alert)
            // アラートにボタンをつける
            alert.addAction(UIAlertAction(title: MESSAGE_YES, style: .default, handler: { action in
                REGIST_CANCEL_FLG = true
                UserDefaults.standard.set(REGIST_CANCEL_FLG, forKey: "scancamera_regist_cancel_flg")
                UIApplication.shared.open(URL(string: SCANCAMERA_INTRODUCTION_URL)!, options: [:], completionHandler: nil)
            }))
            alert.addAction(UIAlertAction(title: MESSAGE_NO, style: .default, handler: { action in}))
            // アラート表示
            getForegroundViewController().present(alert, animated: true, completion: nil)
        }
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
            if GADRewardBasedVideoAd.sharedInstance().isReady {
                let alertController = UIAlertController(title: localText(key:"text_err_usecount_title"),message: localText(key:"text_err_usecount_body"), preferredStyle: UIAlertController.Style.alert)
                let okAction = UIAlertAction(title: localText(key:"btn_ok"), style: UIAlertAction.Style.default){ (action: UIAlertAction) in
                    GADRewardBasedVideoAd.sharedInstance().present(fromRootViewController: self)
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
                if interstitial.isReady {
                    let alertController = UIAlertController(title: localText(key:"text_err_usecount_title"),message: localText(key:"text_err_usecount_body_tap"), preferredStyle: UIAlertController.Style.alert)
                    let okAction = UIAlertAction(title: localText(key:"btn_ok"), style: UIAlertAction.Style.default){ (action: UIAlertAction) in
                        self.interstitial.present(fromRootViewController: self)
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
                        if Maio.canShow(atZoneId: MAIO_ZONEID_REWARD) {
                            let alertController = UIAlertController(title: localText(key:"text_err_usecount_title"),message: localText(key:"text_err_usecount_body"), preferredStyle: UIAlertController.Style.alert)
                            let okAction = UIAlertAction(title: localText(key:"btn_ok"), style: UIAlertAction.Style.default){ (action: UIAlertAction) in
                                Maio.show(atZoneId: MAIO_ZONEID_REWARD)
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
            print("キャンセルをタップした時の処理")
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
        print(langTranslations!.count)
        
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
    //キーボードが閉じられるときの呼び出しメソッド
    func keyboardWillBeHidden(/*notification:NSNotification*/){
        switch transSegment.selectedSegmentIndex {
        case BEFORE_TRANS:
            if  self.registerBtn.isHidden {
                RESULT_TEXT = resultTextView.text
            }else{
                LYRIC_RESULT_TEXT = resultTextView.text
            }
        case AFTER_TRANS:
            if  self.registerBtn.isHidden {
                TRANS_TEXT = resultTextView.text
            }else{
                LYRIC_TRANS_TEXT = resultTextView.text
            }
        default: break;
        }
        
        self.scrollResultView.translatesAutoresizingMaskIntoConstraints = false
        UIView.animate(withDuration: 0.1, animations: { () in
            let frame = CGRect(x:self.scrollResultView.frame.origin.x, y:self.scrollResultView.frame.origin.y, width:self.scrollResultView.frame.width, height:CGFloat(self.textAreaEditHeihgt))
            self.scrollResultView.frame = frame
            //self.scrollResultView.translatesAutoresizingMaskIntoConstraints = false
        })
    }
    //キーボードが開くときの呼び出しメソッド
    @objc func keyboardWillBeShown(notification:NSNotification) {
        var tc = UIApplication.shared.keyWindow?.rootViewController;
        while ((tc!.presentedViewController) != nil) {
            tc = tc!.presentedViewController
            
            return
        }
        scrollResultView.translatesAutoresizingMaskIntoConstraints = true
        let rect = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
    
        let duration: TimeInterval? = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        UIView.animate(withDuration: duration!, animations: { () in
            let frame = CGRect(x:self.scrollResultView.frame.origin.x, y:self.scrollResultView.frame.origin.y, width:self.scrollResultView.frame.width, height:CGFloat(self.textAreaEditHeihgt - (rect?.size.height)! + (self.tabBarController?.tabBar.frame.size.height)! + self.cameraBtn.frame.size.height) )
            self.scrollResultView.frame = frame
        })
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
        
        coachViews.bodyView.nextLabel.textColor = UIColor(red: 0.8, green: 0.0, blue: 0.4, alpha: 1.0)
        
        return (bodyView: coachViews.bodyView, arrowView: coachViews.arrowView)
    }
    
    /*******************************************************************
     広告（Admob と Five）の処理
     *******************************************************************/
    func interstitialWillLeaveApplication(_ ad: GADInterstitial){
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
    func rewardBasedVideoAdDidClose(_ rewardBasedVideoAd: GADRewardBasedVideoAd) {
        GADRewardBasedVideoAd.sharedInstance().load(GADRequest(),
                                                    withAdUnitID: ADMOB_REWARD_TRANS)
        // 報酬を受け取った場合は、ここは通らないようにしたい
        if ADMOB_REWARD_RECEIVED {
//            self.transSegment.selectedSegmentIndex = AFTER_TRANS
//            self.waitView.isHidden = false
//            self.helpBtn.isEnabled = false
            //self.tlansLation()
            ADMOB_REWARD_RECEIVED = false
        }else{
            self.waitView.isHidden = true
            self.helpBtn.isEnabled = true

            if EDIT_FLG {
                // 元に戻す
                if LATEST_LYRIC_RESULT_TEXT == "" {
                    LYRIC_RESULT_TEXT = LATEST_LYRIC_RESULT_TEXT
                }else{
                    LYRIC_RESULT_TEXT = resultTextView.text
                }
                if LYRIC_RESULT_TEXT != ""{
                    resultTextView.text = LYRIC_RESULT_TEXT
                }
            }else{
                // 元に戻す
                if LATEST_RESULT_TEXT != "" {
                    RESULT_TEXT = LATEST_RESULT_TEXT
                }else{
                    RESULT_TEXT = resultTextView.text
                }
                if RESULT_TEXT != ""{
                    resultTextView.text = RESULT_TEXT
                }
            }
//
//            if EDIT_FLG {
//                // 元に戻す
//                if LATEST_LYRIC_RESULT_TEXT == "" {
//                    LYRIC_RESULT_TEXT = LATEST_LYRIC_RESULT_TEXT
//                }else{
//                    LYRIC_RESULT_TEXT = resultTextView.text
//                }
//            }else{
//                // 元に戻す
//                if LATEST_RESULT_TEXT != "" {
//                    RESULT_TEXT = LATEST_RESULT_TEXT
//                }else{
//                    RESULT_TEXT = resultTextView.text
//                }
//            }
            self.transSegment.selectedSegmentIndex = BEFORE_TRANS
        }
    }
    func rewardBasedVideoAd(_ rewardBasedVideoAd: GADRewardBasedVideoAd,
                            didRewardUserWith reward: GADAdReward) {
        
        ADMOB_REWARD_RECEIVED = true
        TRANS_REWARD_COUNT = TRANS_REWARD_COUNT + Int(truncating: reward.amount)
        if TRANS_REWARD_COUNT < -5 {
            TRANS_REWARD_COUNT = -5
        }
        UserDefaults.standard.set(TRANS_REWARD_COUNT, forKey: "transCount")
        self.transSegment.selectedSegmentIndex = AFTER_TRANS
        self.waitView.isHidden = false
        self.helpBtn.isEnabled = false
        self.tlansLation()
    }
    
    func rewardBasedVideoAdDidReceive(_ rewardBasedVideoAd:GADRewardBasedVideoAd) {
        print("Reward based video ad is received.")
    }
    
    func rewardBasedVideoAdDidOpen(_ rewardBasedVideoAd: GADRewardBasedVideoAd) {
        print("Opened reward based video ad.")
    }

    
    func rewardBasedVideoAdDidStartPlaying(_ rewardBasedVideoAd: GADRewardBasedVideoAd) {
        print("Reward based video ad started playing.")
    }
    
    func rewardBasedVideoAdDidCompletePlaying(_ rewardBasedVideoAd: GADRewardBasedVideoAd) {
        print("Reward based video ad has completed.")
    }
    func rewardBasedVideoAdWillLeaveApplication(_ rewardBasedVideoAd: GADRewardBasedVideoAd) {
        print("Reward based video ad will leave application.")
        
    }
    
    func rewardBasedVideoAd(_ rewardBasedVideoAd: GADRewardBasedVideoAd,
                            didFailToLoadWithError error: Error) {
        print("Reward based video ad failed to load.")
    }
    // maio
    //- (void)maioDidClickAd:(NSString *)zoneId;
    func maioDidClickAd(_ zoneId: String) {
        if zoneId == MAIO_ZONEID_INTERSTISHAL{
            MAIO_TAP_FLG = true
        }
        MAIO_TAP_FLG = true
    }
    func maioDidCloseAd(_ zoneId: String) {
        // 広告がクリックされた際に呼び出される処理
        if zoneId == MAIO_ZONEID_INTERSTISHAL{
            if MAIO_TAP_FLG {
                TRANS_REWARD_COUNT = TRANS_REWARD_COUNT + TRAN_AD_INTERVAL
                if TRANS_REWARD_COUNT < -5 {
                    TRANS_REWARD_COUNT = -5
                }
                UserDefaults.standard.set(TRANS_REWARD_COUNT, forKey: "transCount")
                self.waitView.isHidden = false
                self.FROM_TRAND_AD = false
                self.tlansLation()
            }else{
                self.transSegment.selectedSegmentIndex = BEFORE_TRANS
            }
        }
        if MAIO_TAP_FLG {
            TRANS_REWARD_COUNT = TRANS_REWARD_COUNT + TRAN_AD_INTERVAL
            if TRANS_REWARD_COUNT < -5 {
                TRANS_REWARD_COUNT = -5
            }
            UserDefaults.standard.set(TRANS_REWARD_COUNT, forKey: "transCount")
            self.waitView.isHidden = false
            self.FROM_TRAND_AD = false
            self.tlansLation()
        }
        MAIO_TAP_FLG = false
    }
//    - (void)maioDidFinishAd:(NSString *)zoneId playtime:(NSInteger)playtime skipped:(BOOL)skipped rewardParam:(NSString *)rewardParam;
    func maioDidFinishAd(_ zoneId: String, playtime: Int, skipped:Bool, rewardParam:String){
        // 広告視聴完了の際に呼び出される処理
        if zoneId == MAIO_ZONEID_REWARD{
            ADMOB_REWARD_RECEIVED = true
            TRANS_REWARD_COUNT = TRANS_REWARD_COUNT + Int(3)
            if TRANS_REWARD_COUNT < -5 {
                TRANS_REWARD_COUNT = -5
            }
            UserDefaults.standard.set(TRANS_REWARD_COUNT, forKey: "transCount")
            self.waitView.isHidden = true
            self.tlansLation()
            self.transSegment.selectedSegmentIndex = AFTER_TRANS
        }else{
            
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
        print(FADAdInterface.self)
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
        print(errorCode)
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
            DispatchQueue.global(qos: .default).async {
                self.getLanguages()
            }
        } else {
            print("Network not reachable")
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
        
    }
    // オブジェクト破棄時に監視を解除
    deinit {
        //イベントリスナーの削除
        NotificationCenter.default.removeObserver(self)
    }
}
extension scanViewController : UIViewControllerTransitioningDelegate{
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        transition.transitionMode = .present
        transition.startingPoint = CGPoint(x:myAppFrameSize.width / 2 ,y:myAppFrameSize.height - cameraBtn.center.y + (cameraBtn.frame.height / 4))
        transition.bubbleColor = UIColor.black
        return transition
    }
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        transition.transitionMode = .dismiss
        transition.startingPoint =  CGPoint(x:myAppFrameSize.width / 2 ,y:myAppFrameSize.height - cameraBtn.center.y + (cameraBtn.frame.height / 4))
        transition.bubbleColor = UIColor.black
        return transition
    }
    
}
