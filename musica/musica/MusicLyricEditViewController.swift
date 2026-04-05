
//
//  musicLyricEditViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2017/05/14.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import AVFoundation
import CoreData
import GoogleMobileAds

class musicLyricEditViewController: UIViewController , UITextViewDelegate{

    /*
     ボタン関連
     */
    @IBOutlet weak var bannerView: BannerView!
    @IBOutlet weak var keyBoardClouseBtn: UIButton!
    @IBOutlet weak var textScrollView: UIScrollView!
    @IBOutlet weak var LyricTextView: UIView!
    @IBOutlet weak var LyricEditTextView: UITextView!
    @IBOutlet weak var lyricEditModeSelecter: UISegmentedControl!
    @IBOutlet weak var LyricCameraView: UIView!
    @IBOutlet weak var camera: UIButton!
    var color = UIColor.lightGray
    
    /*
     テキスト編集関連
     */
    // text編集のための変数
    var isObserving = false
    var editLibraryName = ""
    var editTrackUrl : URL! = nil
    var nowLyricText = ""
    var editPlayNum = 0
    var editShffuleFromTypeFlg = true
    var target:UIView! //タップされた部品
    var textViewSize = CGRect()
    @IBOutlet weak var textEditAreaView: UIView!
    var textAreaEditHeihgtAdjustment:CGFloat = 0
    var textAreaEditEndHeihgt:CGFloat = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()

        /*
         端末によるサイズの計算とviewの設定
         */
        // 編集する情報のタイトルセット
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: " ", style: .plain, target: nil, action: nil)
        
        // text編集周り
        LyricEditTextView.delegate = self
        LyricEditTextView.text = nowLyricText
        textViewSize = textScrollView.frame
        //textAreaEditEndHeihgt = myAppFrameSize.height - (tabBarController?.tabBar.frame.size.height)! - UIApplication.shared.statusBarFrame.height - (navigationController?.navigationBar.frame.size.height)!
        
        switch Int(myAppFrameSize.height) {

        case IPHONE_5_HEIGHT:
            textAreaEditHeihgtAdjustment = self.bannerView.frame.size.height + 8
            textAreaEditEndHeihgt = 360
        case IPHONE_6_HEIGHT:
            textAreaEditHeihgtAdjustment = self.bannerView.frame.size.height + 8
            textAreaEditEndHeihgt = 460
        case IPHONE_6PLUS_HEIGHT:
            textAreaEditHeihgtAdjustment = self.bannerView.frame.size.height + 8
            textAreaEditEndHeihgt = 530
        case IPHONEX_HEIGHT:
            textAreaEditHeihgtAdjustment = ((self.tabBarController?.tabBar.frame.size.height)! + 8)
            textAreaEditEndHeihgt = 543

        default:
            textAreaEditHeihgtAdjustment = self.bannerView.frame.size.height + 8
            textAreaEditEndHeihgt = textScrollView.frame.size.height
        }
        textScrollView.translatesAutoresizingMaskIntoConstraints = true

        LyricEditTextView.font = UIFont(name: "GeezaPro", size: CGFloat(SETTING_LYRIC_SIZE_NUM_ARRAY[SETTING_LYRIC_SIZE_NUM]))
        
        // キーボード閉じるボタンはデフォルトでは表示しない
        keyBoardClouseBtn.isHidden = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.keyboardWillBeShown(notification:)),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )
        // Viewの設定
        LyricCameraView.isHidden = true
        
        if #available(iOS 10.0, *) {
            camera.isEnabled = true
        } else {
            camera.isEnabled = false
            camera.backgroundColor = UIColor.lightGray
        }

    }
    /*******************************************************************
     画面描画時の処理
     **************************************************************var**/
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        selectMusicView.isHidden = true
        // navigationbarの色設定
        color = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        keyBoardClouseBtn.setTitleColor(self.color, for: .normal)
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
        
        /*
         広告関連
         */
        // AdMobバナー広告の読み込み
        if AD_DISPLAY_MUSIC_LYRIC_EDIT_BANNER {
            bannerView.adUnitID = ADMOB_BANNER_ADUNIT_ID
            bannerView.rootViewController = self
            custumLoadBannerAd(bannerView: self.bannerView,setBannerView:self.view)
        }else{
            bannerView.isHidden = true
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    /*******************************************************************
     ボタンタップ時処理
     *******************************************************************/
    // 歌詞設定画面を切り替える
    @IBAction func lyricEditViewChenged(_ sender: Any) {
        //セグメント番号で条件分岐させる
        switch (sender as AnyObject).selectedSegmentIndex {
        case 0:
            LyricCameraView.isHidden = true
            LyricTextView.isHidden = false
        case 1:
            LyricCameraView.isHidden = false
            LyricTextView.isHidden = true
            //キーボードを閉じる
            LyricEditTextView.resignFirstResponder()
            keyboardWillBeHidden()
        case 2:
            LyricCameraView.isHidden = false
            LyricTextView.isHidden = true
            //キーボードを閉じる
            LyricEditTextView.resignFirstResponder()
            keyboardWillBeHidden()
        default:
            print("該当無し")
        }
        /*
         広告関連
         */
        // AdMobバナー広告の読み込み
        if AD_DISPLAY_MUSIC_LYRIC_EDIT_BANNER {
            bannerView.adUnitID = ADMOB_BANNER_ADUNIT_ID
            bannerView.rootViewController = self
            custumLoadBannerAd(bannerView: self.bannerView,setBannerView:self.view)
        }
    }
    // 「カメラボタン」タップ時
    @IBAction func cameraBtnTapped(_ sender: Any) {
        let storyboard: UIStoryboard = self.storyboard!
        let nextView = storyboard.instantiateViewController(withIdentifier: "cameraView")
        present(nextView, animated: true, completion: nil)
    }
    // 歌詞を登録する
    @IBAction func resistLyricBtnTapped(_ sender: Any) {
        
        var msgTitle = ""
        var msgBody = ""
        
        // アラートを作成
        let alert = UIAlertController(
            title: CONFIRM_DIALOGUE_TITLE_UPDATE_LYLIC_DATA,
            message: LyricEditTextView.text,
            preferredStyle: .alert)
        
        // アラートにボタンをつける
        let action1 = UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: {
            (action: UIAlertAction!) in
            // 更新処理へ進む
            let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
            let context:NSManagedObjectContext = appDelegate.managedObjectContext
            let fetchRequest:NSFetchRequest<MusicModel> = MusicModel.fetchRequest()
            let predicate = NSPredicate(format:"%K = %@","musicLibraryName",self.editLibraryName)
            fetchRequest.predicate = predicate
            let fetchData = try! context.fetch(fetchRequest)
            if(!fetchData.isEmpty){
//                var url = ""
//                do {
//                    url = try String(contentsOf: self.editTrackUrl)
//
//                } catch {
//                }
//                var trackTitle = ""
//                for i in 0..<fetchData.count{
//                    if URL(string: fetchData[i].url!) == self.editTrackUrl! {
//                        fetchData[i].lyric = self.LyricEditTextView.text
//                        if self.editShffuleFromTypeFlg == false {
//                            trackTitle = displayMusicLibraryData.trackData[self.editPlayNum].title
//                        } else {
//                            if SHUFFLE_FLG{
//                                trackTitle = NowPlayingMusicLibraryData.trackDataShuffled[self.editPlayNum].title
//                            }else{
//                                trackTitle = NowPlayingMusicLibraryData.trackData[self.editPlayNum].title
//                            }
//                        }
//                        break
//                    }
//                }
                // 更新内容を保存
                do{
                    try context.save()
                    msgBody = SUCCESS_DIALOGUE_MESSAGE_UPDATE_LYLIC_DATA
                    if self.editShffuleFromTypeFlg  == false {
                        // 音楽一覧画面からの遷移時
                        displayMusicLibraryData.trackData[self.editPlayNum].lyric = self.LyricEditTextView.text
                        if displayMusicLibraryData.musicLibraryCode == NowPlayingMusicLibraryData.musicLibraryCode {
                            if SHUFFLE_FLG{
                                var nowPlayS = 0
                                for i in 0...NowPlayingMusicLibraryData.trackData.count - 1 {
                                    if NowPlayingMusicLibraryData.trackDataShuffled[self.editPlayNum].url == displayMusicLibraryData.trackData[i].url{
                                        nowPlayS = i
                                        break
                                    }
                                }
                                displayMusicLibraryData.trackData[nowPlayS].lyric = self.LyricEditTextView.text
                                displayMusicLibraryData.trackDataShuffled[self.editPlayNum].lyric = self.LyricEditTextView.text
                                NowPlayingMusicLibraryData.trackData[nowPlayS].lyric  = self.LyricEditTextView.text
                                NowPlayingMusicLibraryData.trackDataShuffled[self.editPlayNum].lyric  = self.LyricEditTextView.text
                            }else{
                                var nowPlay = 0
                                for i in 0...NowPlayingMusicLibraryData.trackDataShuffled.count - 1 {
                                    if displayMusicLibraryData.trackData[self.editPlayNum].url == NowPlayingMusicLibraryData.trackDataShuffled[i].url{
                                        nowPlay = i
                                        break
                                    }
                                }
                                displayMusicLibraryData.trackData[self.editPlayNum].lyric = self.LyricEditTextView.text
                                displayMusicLibraryData.trackDataShuffled[nowPlay].lyric = self.LyricEditTextView.text
                                NowPlayingMusicLibraryData.trackData[self.editPlayNum].lyric  = self.LyricEditTextView.text
                                NowPlayingMusicLibraryData.trackDataShuffled[nowPlay].lyric  = self.LyricEditTextView.text
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
                            NowPlayingMusicLibraryData.trackData[nowPlayS].lyric = self.LyricEditTextView.text
                            NowPlayingMusicLibraryData.trackDataShuffled[self.editPlayNum].lyric = self.LyricEditTextView.text
                            if displayMusicLibraryData.musicLibraryCode == NowPlayingMusicLibraryData.musicLibraryCode {
                                displayMusicLibraryData.trackDataShuffled[self.editPlayNum].lyric = self.LyricEditTextView.text
                                displayMusicLibraryData.trackData[nowPlayS].lyric = self.LyricEditTextView.text
                            }
                        }else{
                            var nowPlay = 0
                            for i in 0...NowPlayingMusicLibraryData.trackDataShuffled.count - 1 {
                                if NowPlayingMusicLibraryData.trackData[self.editPlayNum].url == NowPlayingMusicLibraryData.trackDataShuffled[i].url{
                                    nowPlay = i
                                    break
                                }
                            }
                            NowPlayingMusicLibraryData.trackData[self.editPlayNum].lyric = self.LyricEditTextView.text
                            NowPlayingMusicLibraryData.trackDataShuffled[nowPlay].lyric = self.LyricEditTextView.text
                            if displayMusicLibraryData.musicLibraryCode == NowPlayingMusicLibraryData.musicLibraryCode {
                                displayMusicLibraryData.trackDataShuffled[nowPlay].lyric = self.LyricEditTextView.text
                                displayMusicLibraryData.trackData[self.editPlayNum].lyric = self.LyricEditTextView.text
                            }
                        }
                    }
                }catch{
                    print(error)
                    msgTitle = MESSAGE_FAILURE
                    msgBody = FAILURE_DIALOGUE_MESSAGE_UPDATE_LYLIC_DATA
                }
                self.editShffuleFromTypeFlg = true
                showToastMsg(messege:msgBody,time:2.0, tab: COLOR_THEMA.SEARCH.rawValue)
//                // アラートを作成
//                let resuleAlert = UIAlertController(
//                    title: msgTitle,
//                    message: msgBody,
//                    preferredStyle: .alert)
//                // アラートにボタンをつける
//                let okBtn = UIAlertAction(title: MESSAGE_OK, style: UIAlertAction.Style.default, handler: {
//                    (action: UIAlertAction!) in
//                })
//                resuleAlert.addAction(okBtn)
//
//                // アラート表示
//                self.present(resuleAlert, animated: true, completion: nil)
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
    
    //「閉じるボタン」で呼び出されるメソッド
    @IBAction func keyBoardClouseBtnTapped(_ sender: Any) {
        //キーボードを閉じる
        LyricEditTextView.resignFirstResponder()
        keyboardWillBeHidden()
    }

    /*******************************************************************
     テキスト編集周りの処理
     *******************************************************************/
    //キーボードが閉じられるときの呼び出しメソッド
    func keyboardWillBeHidden(/*notification:NSNotification*/){
        keyBoardClouseBtn.isHidden = true
        UIView.animate(withDuration: 0.1, animations: { () in
            self.textScrollView.frame.size.height = self.textAreaEditEndHeihgt
        })
    }

    //キーボードが開くときの呼び出しメソッド
    @objc func keyboardWillBeShown(notification:NSNotification) {
        if keyBoardClouseBtn.isHidden {
            let rect = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            let duration: TimeInterval? = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
            UIView.animate(withDuration: duration!, animations: { () in
                self.textScrollView.translatesAutoresizingMaskIntoConstraints = true
                self.textScrollView.frame.size.height = self.textAreaEditEndHeihgt - (rect?.size.height)! + self.textAreaEditHeihgtAdjustment
                self.textScrollView.frame.origin.y = self.textViewSize.origin.y
            })
            // キーボード閉じるボタンを表示
            keyBoardClouseBtn.isHidden = false
        }
    }
    
    /*******************************************************************
     画面遷移時処理
     *******************************************************************/
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    // オブジェクト破棄時に監視を解除
    deinit {
        //イベントリスナーの削除
        NotificationCenter.default.removeObserver(self)
    }
    override var shouldAutorotate: Bool {
        get {
            return false
        }
    }
}
