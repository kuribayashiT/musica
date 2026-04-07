//
//  PlayMusicViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2017/05/12.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer
import GoogleMobileAds
import MultiSlider

class PlayMusicViewController: UIViewController, AVAudioPlayerDelegate , UIPickerViewDelegate, UIPickerViewDataSource ,FullScreenContentDelegate{

    /* ボタン関連 */
    @IBOutlet weak var mojiSizeBtn: UIButton!
    @IBOutlet weak var BeforeBtn: UIButton!
    @IBOutlet weak var AfterBtn: UIButton!
    @IBOutlet weak var PlayBtn: UIButton!
    @IBOutlet weak var musicProgressSlider: UISlider!
    @IBOutlet weak var multiRepeatSlider: MultiSlider!
    @IBOutlet weak var speedPicker: UIPickerView!
    @IBOutlet weak var repeatBtn: UIButton!
    @IBOutlet weak var shuffleBtn: UIButton!
    @IBOutlet weak var adRemoveBtn: UIButton!
    @IBOutlet weak var repeatSwitch: UISegmentedControl!
    @IBOutlet weak var repeatSettingBtn: UIButton!
    @IBOutlet weak var musicControllerMgn: NSLayoutConstraint!
    @IBOutlet weak var musicControllerView: UIView!
    @IBOutlet weak var musicTitleBar: UINavigationItem!
    var interstitial: InterstitialAd?
    /* レイアウト関連 */
    @IBOutlet weak var banner: BannerView!
    @IBOutlet weak var bannerHeight: NSLayoutConstraint!
    @IBOutlet weak var musicArtViewDefaultHeight: NSLayoutConstraint!
    @IBOutlet weak var musicArtView4InchHeight: NSLayoutConstraint!
    @IBOutlet weak var sectionPlayLabel: UILabel!
    
    /* 音楽関連 */
    // 再生中の音楽データ
    var musicLibraryName : String = ""
    var musicArtWorkImg : UIImage? = nil
    @IBOutlet weak var MusicArtWorkView: UIView!
    var shadowView = UIView()
    var musicArtWorkImgView = UIImageView()
    
    @IBOutlet weak var LyricView: UIVisualEffectView!
    @IBOutlet weak var LyricTextView: UITextView!
    @IBOutlet weak var lyricSegmentetion: UISegmentedControl!
    @IBOutlet weak var LyricBGView: UIVisualEffectView!
    // 再生時間
    @IBOutlet weak var musicTotalTime: UILabel!
    @IBOutlet weak var musicNowTime: UILabel!
    @IBOutlet weak var repeatMinTime: UILabel!
    @IBOutlet weak var repeatMaxTime: UILabel!
    var timer: Timer!
    var rewardedAd: RewardedAd?
    // 総再生数
    var playListNum : Int = 0
    
    // 音楽再生のためのplayer
    let mMusicController = MusicController()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        /*  端末によるサイズの計算とviewの設定 */
        let backButton = UIBarButtonItem()
        backButton.title = " "
        self.navigationItem.backBarButtonItem = backButton
        MusicArtWorkView.isHidden = false
        LyricTextView.font = AppFont.lyric(sizeIndex: SETTING_LYRIC_SIZE_NUM)
        mojiSizeBtn.setTitle(SETTING_LYRIC_SIZE_NAME_ARRAY[SETTING_LYRIC_SIZE_NUM], for: .normal)
        mojiSizeBtn.isHidden = true
        musicArtWorkImgView.clipsToBounds = true
        shadowView.layer.shadowOpacity = 1
        shadowView.layer.shadowOffset = .zero
        shadowView.layer.shadowRadius = 10
        shadowView.layer.cornerRadius = 5
        shadowView.backgroundColor = darkModeIconBlackUIcolor()
        musicArtWorkImgView.backgroundColor = AppColor.playerBackground
        musicArtWorkImgView.layer.cornerRadius = 5
        speedPicker.delegate = self
        speedPicker.dataSource = self
        musicArtWorkImgView.contentMode = .center
        musicProgressSlider.setThumbImage(UIImage(named: "slider"), for: .normal)
        multiRepeatSlider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)
        multiRepeatSlider.valueLabelPosition = .notAnAttribute
        multiRepeatSlider.isHapticSnap = false
        multiRepeatSlider.showsThumbImageShadow = true
        sectionPlayLabel.text = localText(key:"musiclibrary_play_section_label")
        BeforeBtn.setImage(playBackLBtnImage, for: .normal)
        BeforeBtn.tintColor = darkModeIconBlackUIcolor()
        PlayBtn.tintColor = darkModeIconBlackUIcolor()
        AfterBtn.setImage(playNextLBtnImage, for: .normal)
        AfterBtn.tintColor = darkModeIconBlackUIcolor()
        if isDarkMode(vc: self){
            LyricView.effect = UIBlurEffect(style: .dark)
            LyricBGView.isHidden = true
        }else{
            LyricView.effect = UIBlurEffect(style: .light)
            LyricBGView.isHidden = false
        }

        // ── デザインシステム適用・プリセット速度UI追加 ──
        setupPlayerUI()
    }
    override func viewDidAppear(_ animated: Bool) {
        if topViewController(controller: getForegroundViewController()) is PlayMusicViewController {
            // 特に何もしない
        }else{
            if audioPlayer != nil {
                audioPlayer.stop()
            }
        }
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if isDarkMode(vc: self){
            LyricView.effect = UIBlurEffect(style: .dark)
            LyricBGView.isHidden = true
        }else{
            LyricView.effect = UIBlurEffect(style: .light)
            LyricBGView.isHidden = false
        }
    }
    /*******************************************************************
     画面描画時の処理
     *******************************************************************/
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if self.view.viewWithTag(101) != nil && self.view.viewWithTag(100) != nil{
            //print("Continue")
        }else{
            shadowView.tag = 100
            musicArtWorkImgView.tag = 101
            
            // 音楽コントローラー/広告のレイアウト
            adRemoveBtn.isHidden = true
            banner.isHidden = false
            banner.backgroundColor = AppColor.playerBackground
            var OS11upFlg = false
            if #available(iOS 11.0, *){
                // iOS11 以降の場合
                OS11upFlg = true
            }else {
                // iOS10 以前の場合 # iOS10はNSLayoutConstraintが正しく反映されないため、バナーは常に非表示。
                OS11upFlg = false
            }
            if OS11upFlg && ADApearFlg() && AD_DISPLAY_MUSICLIBRARYLIST_BANNER {
                banner.isHidden = false
                adRemoveBtn.isHidden = false
                //bannerHeight.constant = banner.frame.height
            }else{
                banner.isHidden = true
                //bannerHeight.constant = 5.0
            }
            
            // musicArt/歌詞エリア のレイアウト
            switch Int(myAppFrameSize.height) {
            case IPHONE_5_HEIGHT:
                musicArtViewDefaultHeight.isActive = false
                musicArtView4InchHeight.isActive = true
            case IPHONE_6_HEIGHT:
                musicArtViewDefaultHeight.isActive = false
                musicArtView4InchHeight.isActive = true
            case IPHONE_6PLUS_HEIGHT:
                musicArtViewDefaultHeight.isActive = true
                musicArtView4InchHeight.isActive = false
            case IPHONEX_HEIGHT:
                musicArtViewDefaultHeight.isActive = true
                musicArtView4InchHeight.isActive = false
            case IPHONEXSMAX_HEIGHT:
                musicArtViewDefaultHeight.isActive = true
                musicArtView4InchHeight.isActive = false
            default:
                musicArtViewDefaultHeight.isActive = true
                musicArtView4InchHeight.isActive = false
            }
            
            // サムネイル/歌詞 表示エリアのレイアウト(musicArt/歌詞エリアのレイアウトが確定してから実行)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) {
                if self.MusicArtWorkView.frame.size.height > self.MusicArtWorkView.frame.size.width {
                    self.MusicArtWorkView.frame.size.height = self.MusicArtWorkView.frame.size.width
                }
                let imagW = Double((self.MusicArtWorkView.frame.size.height) * 10 / 11)
                self.shadowView.frame.size = CGSize(width:  imagW - 2 ,height: imagW - 2)
                self.shadowView.center = self.MusicArtWorkView.center
                self.musicArtWorkImgView.frame.size = CGSize(width:  imagW,height: imagW)
                self.musicArtWorkImgView.center = self.MusicArtWorkView.center
                self.view.addSubview(self.shadowView)
                self.view.addSubview(self.musicArtWorkImgView)
                self.view.sendSubviewToBack(self.musicArtWorkImgView)
                self.view.sendSubviewToBack(self.shadowView)
                self.LyricView.bringSubviewToFront(self.view)
            }
            
            // レイアウトに現在の状況を反映
            if audioPlayer != nil {
                if audioPlayer.isPlaying{
                   musicImageTrans(v1 : self.musicArtWorkImgView, v2 : self.shadowView, type:1)
                }else{
                    musicImageTrans(v1 : self.musicArtWorkImgView, v2 : self.shadowView, type:1)
                }
                repeatMaxTime.text = formatTimeString(d: audioPlayer.duration)
            }
        }
    }
    override func viewWillAppear(_ animated: Bool) {
        
        LYRIC_RESULT_TEXT = ""
        // navigationbarの色設定
        setNavigationberStyle(naviBar:self.navigationController!.navigationBar,place:COLOR_THEMA.HOME.rawValue)
        if ADApearFlg() {
            RewardedAd.load(with: ADMOB_REWARD_AD, request: Request()) { [weak self] ad, error in
                if let error = error { print("RewardedAd failed to load: \(error)"); return }
                self?.rewardedAd = ad
                self?.rewardedAd?.fullScreenContentDelegate = self
            }
            // 広告の準備
            loadInterstitial()
            if AD_DISPLAY_MUSICLIBRARYLIST_BANNER {
                banner.isHidden = false
                banner.adUnitID = ADMOB_BANNER_ADUNIT_ID
                banner.rootViewController = self
                custumLoadBannerAd(bannerView: self.banner,setBannerView:self.view)
            }
        }
        // バックグラウンドでも再生できるカテゴリに設定する
        setBGPlayCommand()
        speedPicker.selectRow(speedRow, inComponent: 0, animated: true)
        repeatSwitch.selectedSegmentIndex = sectionRepeatStatus
        liricImgStateSegment(nowSegment : LYRIC_IMG_SEGMENT_STATE)
        repeatImgStateSegment(nowSegment : repeatState)
        // 速度プリセットUI・状態ラベルの復元
        restoreSpeedUI()
        updateShuffleLabel()
        updateRepeatLabel()
        // 音楽再生
        if SHUFFLE_FLG == false {
            shuffleBtn.setImage(UIImage(named: "shuffle")?.withRenderingMode(.alwaysTemplate), for: .normal)
            shuffleBtn.tintColor = AppColor.inactive
            if audioPlayer == nil {
/*!DEBUG!*/     playMusicWrapper(playData: NowPlayingMusicLibraryData.trackDataShuffled[newSelectPlayNum])
            }else{
                if audioPlayer.isPlaying{
                    self.PlayBtn.setImage(stopBtnLImage, for: .normal)
                }else{
                    self.PlayBtn.setImage(playBtnLImage, for: .normal)
                }
                if NowPlayingMusicLibraryData.nowPlaying != NOW_NOT_PLAYING && NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying].url == NowPlayingMusicLibraryData.trackData[newSelectPlayNum].url {
                    updateTrackData(playData: NowPlayingMusicLibraryData.trackData[newSelectPlayNum],beginningFlg:false)
                    audioPlayer.delegate = nil
                    audioPlayer.delegate = self  
                    setSectionRepeatStatus()
                    
                    if timer == nil || timer.isValid == false {
                        timer = Timer.scheduledTimer(timeInterval: 0.02, target: self, selector: #selector(self.updateNowTime), userInfo: nil, repeats: true)
                        timer.fire()
                    }
                    return
                }else{
                    // 再生中の曲とライアブラリを更新
                    NowPlayingMusicLibraryData.nowPlayingLibrary = musicLibraryName
                    NowPlayingMusicLibraryData.nowPlaying = newSelectPlayNum
                }
            }
/*!DEBUG!*/ playMusicWrapper(playData: NowPlayingMusicLibraryData.trackData[newSelectPlayNum])
        }else{
            shuffleBtn.setImage(UIImage(named: "shuffle")?.withRenderingMode(.alwaysTemplate), for: .normal)
            shuffleBtn.tintColor = AppColor.accent
            if audioPlayer == nil {
                playMusicWrapper(playData: NowPlayingMusicLibraryData.trackDataShuffled[newSelectPlayNum])
            }else{
                if audioPlayer.isPlaying{
                    self.PlayBtn.setImage(stopBtnLImage, for: .normal)
                }else{
                    self.PlayBtn.setImage(playBtnLImage, for: .normal)
                }
                if NowPlayingMusicLibraryData.nowPlaying != NOW_NOT_PLAYING && NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying].url == NowPlayingMusicLibraryData.trackDataShuffled[newSelectPlayNum].url {
                    updateTrackData(playData: NowPlayingMusicLibraryData.trackDataShuffled[newSelectPlayNum],beginningFlg:false)
                    audioPlayer.delegate = nil
                    audioPlayer.delegate = self
                    setSectionRepeatStatus()
                    if timer == nil || timer.isValid == false {
                        timer = Timer.scheduledTimer(timeInterval: 0.02, target: self, selector: #selector(self.updateNowTime), userInfo: nil, repeats: true)
                        timer.fire()
                    }
                    return
                }else{
                    // 再生中の曲とライアブラリを更新
                    NowPlayingMusicLibraryData.nowPlayingLibrary = musicLibraryName
                    NowPlayingMusicLibraryData.nowPlaying = newSelectPlayNum
                }
            }
            playMusicWrapper(playData: NowPlayingMusicLibraryData.trackDataShuffled[newSelectPlayNum])
        }
        if timer == nil || timer.isValid == false {
            timer = Timer.scheduledTimer(timeInterval: 0.02, target: self, selector: #selector(self.updateNowTime), userInfo: nil, repeats: true)
            timer.fire()
        }
        setSectionRepeatStatus()
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    /*******************************************************************
     picker Delegate
     *******************************************************************/
     func numberOfComponents(in pickerView: UIPickerView) -> Int {
         return 1
     }
     func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
         return speedList.count
     }
//     func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
//         return String(speedList[row])
//     }
     func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
         speedRow = row
         let speed = speedList[speedRow] * 10
         audioPlayer.rate = Float(round(speed) / 10)
     }
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int,
            forComponent component: Int, reusing view: UIView?) -> UIView
    {
        let label = (view as? UILabel) ?? UILabel()
        label.text = String(speedList[row])
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        return label
    }
    /*******************************************************************
     広告取得処理
     *******************************************************************/
    func loadInterstitial() {
        InterstitialAd.load(with: ADMOB_INTERSTITIAL_LIBRARY, request: Request()) { [weak self] ad, error in
            if let error = error { print("Interstitial failed to load: \(error)"); return }
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
        }
    }
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        loadInterstitial()
        RewardedAd.load(with: DEBUG_FLG ? ADMOB_REWARD_TRANS_test : ADMOB_REWARD_AD, request: Request()) { [weak self] ad, error in
            if let error = error { return }
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
        }
        if SHUFFLE_FLG {
            playMusicWrapper(playData: NowPlayingMusicLibraryData.trackDataShuffled[newSelectPlayNum])
            if audioPlayer != nil { audioPlayer.stop() }
        }else{
            playMusicWrapper(playData: NowPlayingMusicLibraryData.trackData[newSelectPlayNum])
            if audioPlayer != nil { audioPlayer.stop() }
        }
    }
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
      if audioPlayer != nil {
          audioPlayer.stop()
      }
    }
    func adWillLeaveApplication(_ ad: FullScreenPresentingAd) {
        self.dismiss(animated: true, completion: nil)
    }
    /*******************************************************************
     ボタンタップ時処理
     *******************************************************************/
    // 区間リピートスイッチ
    @IBAction func repeatSwitchChange(_ sender: Any) {
        //セグメント番号で条件分岐させる
        sectionRepeatStatus = (sender as AnyObject).selectedSegmentIndex
        setSectionRepeatStatus()
    }
    // 区間リピート設定
    @IBAction func sectionRepeatSetBtnTapped(_ sender: Any) {
        if sectionRepeatEditFlg {
            sectionRepeatEditFlg = false
            repeatSettingBtn.setTitle(localText(key:"musiclibrary_play_section_repeat_setting"), for: .normal)
            // ここでUSERDEFAULTに設定
            if SHUFFLE_FLG {
                mMusicController.setSectionRepeatSettings(playData : NowPlayingMusicLibraryData.trackDataShuffled[newSelectPlayNum],time: multiRepeatSlider.value)
            }else{
                mMusicController.setSectionRepeatSettings(playData : NowPlayingMusicLibraryData.trackData[newSelectPlayNum],time: multiRepeatSlider.value)
            }
        }else{
            sectionRepeatEditFlg = true
            repeatSettingBtn.setTitle(localText(key:"musiclibrary_play_section_repeat_setting_comp"), for: .normal)
        }
        setSectionRepeatEditStatus()
    }
    // 「広告非表示」ボタン
    @IBAction func adRemoveBtnTapped(_ sender: Any) {
        removeADAlertApear(vc:self,rewardedAd: rewardedAd) { [weak self] in
            let now = NSDate()
            let date1 = NSDate(timeInterval: TimeInterval(60 * 60 * 3), since: now as Date)
            UserDefaults.standard.set(date1, forKey: "ADdate")
            UserDefaults.standard.synchronize()
            deleteAD()
            self?.loadView()
            self?.viewDidLoad()
        }
    }
    // 「再生▶︎/停止■」ボタン
    @IBAction func PlayBtnTapped(_ sender: Any) {
        // audioPlayer が nil だったら最初の曲を再生
        if audioPlayer == nil {
            if SHUFFLE_FLG == false {
                playMusicWrapper(playData: NowPlayingMusicLibraryData.trackData[newSelectPlayNum])
            }else{
                playMusicWrapper(playData: NowPlayingMusicLibraryData.trackDataShuffled[newSelectPlayNum])
            }
        }else{
            if audioPlayer.isPlaying {
                audioPlayer.stop()
                tapBtnAnimesion(btn: PlayBtn ,image: playBtnLImage)
                musicImageTrans(v1 : self.musicArtWorkImgView, v2 : self.shadowView, type:0)
            }else{
                audioPlayer.play()
                tapBtnAnimesion(btn: PlayBtn ,image: stopBtnLImage)
                musicImageTrans(v1 : self.musicArtWorkImgView, v2 : self.shadowView, type:1)
            }
        }
    }
    // 「◀︎◀︎」タップ時
    @IBAction func BeforeBtnTapped(_ sender: Any) {
        tapBtnAnimesion(btn: BeforeBtn ,image: nil)
        if audioPlayer != nil {
            if sectionRepeatStatus == SECTION_REPEAT_ON{
                var nowPoint : Float = 0.0
                if SHUFFLE_FLG == false {
                    nowPoint = Float(audioPlayer.currentTime - TimeInterval( mMusicController.getSectionRepeatSetting(url:NowPlayingMusicLibraryData.trackData[newSelectPlayNum].url!)[0]) * audioPlayer.duration)
                }else{
                    nowPoint = Float(audioPlayer.currentTime - TimeInterval( mMusicController.getSectionRepeatSetting(url:NowPlayingMusicLibraryData.trackDataShuffled[newSelectPlayNum].url!)[0]) * audioPlayer.duration)
                }
                if nowPoint > 3 {
                    audioPlayer.currentTime = TimeInterval(Float(multiRepeatSlider.value[0]) * Float(audioPlayer.duration))
                }else{
                    prevMusicPlay(flg : false)
                }
            }else{
                if audioPlayer.currentTime > 3 {
                    audioPlayer.currentTime = 0
                }else{
                    prevMusicPlay()
                }
            }
        }
    }
    
    // 「▶︎▶︎」タップ時
    @IBAction func AfterBtnTapped(_ sender: Any) {
        tapBtnAnimesion(btn: AfterBtn ,image: nil)
        NEXT_TAP_FLG = true
        nextMusicPlay()
    }
    
    // 歌詞表示/非表示切り替え設定
    @IBAction func musicLyricDisplaySegmentedTapped(_ sender: Any) {
        //セグメント番号で条件分岐させる
        liricImgStateSegment(nowSegment : (sender as AnyObject).selectedSegmentIndex)
    }
    // 「リピートボタン」タップ時
    @IBAction func repeatBtnTapped(_ sender: Any) {
        repeatImgStateSegment(nowSegment : repeatState, tap:true)
    }
    // 「シャッフルボタン」タップ時
    @IBAction func shuffleBtnTapped(_ sender: Any) {
        if SHUFFLE_FLG {
            SHUFFLE_FLG = false
            shuffleBtn.setImage(UIImage(named: "shuffle")?.withRenderingMode(.alwaysTemplate), for: .normal)
            shuffleBtn.tintColor = AppColor.inactive
            updateShuffleLabel()
            for i in 0...NowPlayingMusicLibraryData.trackData.count - 1 {
                if NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying].url == NowPlayingMusicLibraryData.trackData[i].url{
                    NowPlayingMusicLibraryData.nowPlaying = i
                    newSelectPlayNum = NowPlayingMusicLibraryData.nowPlaying
                    break
                }
            }
        }else{
            SHUFFLE_FLG = true
            shuffleBtn.setImage(UIImage(named: "shuffle")?.withRenderingMode(.alwaysTemplate), for: .normal)
            shuffleBtn.tintColor = AppColor.accent
            updateShuffleLabel()
            for i in 0...NowPlayingMusicLibraryData.trackDataShuffled.count - 1 {
                if NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying].url == NowPlayingMusicLibraryData.trackDataShuffled[i].url{
                    NowPlayingMusicLibraryData.nowPlaying = i
                    newSelectPlayNum = NowPlayingMusicLibraryData.nowPlaying
                    break
                }
            }
        }
    }
    
    // mojiサイズボタンタップ
    @IBAction func mojiSizeBtnTapped(_ sender: Any) {
        mMusicController.setFontSize(textView: self.LyricTextView, btn : mojiSizeBtn)
    }
    // 設定ボタンタップ
    @IBAction func musicSettingBtnTapped(_ sender: Any) {
        performSegue(withIdentifier: "toMusicSetting",sender: "")
    }
    // 再生開始時間の変更
    @IBAction func musicProgressChanged(_ sender: Any) {
        audioPlayer.currentTime = TimeInterval(musicProgressSlider.value * Float(audioPlayer.duration))
    }
    
    /*******************************************************************
     音楽制御処理
     *******************************************************************/
    //再生終了時の呼び出しメソッド
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if endTruckCheckRepeat() {
            return
        }
        nextMusicPlay()
    }
    func endTruckCheckRepeat() -> Bool {
        if NowPlayingMusicLibraryData.nowPlaying == NowPlayingMusicLibraryData.trackData.count - 1{
            switch repeatState {
            case REPEAT_STATE_NONE:
                newSelectPlayNum = 0
                NowPlayingMusicLibraryData.nowPlaying = 0
                PlayBtn.setImage(playBtnLImage, for: .normal)
                musicImageTrans(v1 : self.musicArtWorkImgView, v2 : self.shadowView, type:0)
                if ADApearFlg() {
                    if interstitial != nil {
                        if interstitial != nil {
                            interstitial?.present(from: self)
                        }
                    }
                }
                return true
            case REPEAT_STATE_ALL:
                break
            default:
                break
            }
        }
        return false
    }
    // 音楽再生のためのラッパー関数
    func playMusicWrapper(playData: TrackData){
        // 再生可能かを確認
        if mMusicController.playMusic(playData: playData,vc: self) != CODE_SUCCESS{
            showAlertMsgOneOkBtn(title: ERR_DIALOGUE_TITLE_MUSIC_DATA_NONE,messege: ERR_DIALOGUE_MESSAGE_MUSIC_DATA_NONE)
            // audioPlayer と Viewを更新
            audioPlayer = nil
            PlayBtn.setImage(playBtnLImage, for: .normal)
            return
        }
        audioPlayer.delegate = nil
        audioPlayer.delegate = self
        setSectionRepeatStatus()
        updateTrackData(playData: playData ,beginningFlg:true)
    }
    // 音楽情報の更新
    func updateTrackData(playData: TrackData ,beginningFlg: Bool){
        DispatchQueue.main.async {
            // 曲名をセット
            self.title = playData.title
            // 歌詞をセット
            self.LyricTextView.text = playData.lyric
            self.LyricTextView.contentOffset = CGPoint(x: 0, y: -self.LyricTextView.contentInset.top)
            if playData.artworkImg == nil {
                self.musicArtWorkImgView.image = UIImage(named: "onpu_BL_L")
                self.musicArtWorkImgView.contentMode = .center
            }else{
                self.musicArtWorkImgView.image = playData.artworkImg
                self.musicArtWorkImgView.contentMode = .scaleAspectFit
            }
            
            // 再生中の曲を更新
            NowPlayingMusicLibraryData.nowPlaying = newSelectPlayNum
            self.musicTotalTime.text = formatTimeString(d: audioPlayer.duration)
            self.repeatMinTime.text = "00:00"
            self.repeatMaxTime.text = self.musicTotalTime.text
            self.multiRepeatSlider.value = self.mMusicController.getSectionRepeatSetting(url:playData.url!)
            self.repeatMinTime.text = formatTimeString(d: TimeInterval(self.multiRepeatSlider.value[0]) * audioPlayer.duration)
            self.repeatMaxTime.text = formatTimeString(d: TimeInterval(self.multiRepeatSlider.value[1]) * audioPlayer.duration)
            if beginningFlg {
                if sectionRepeatStatus == SECTION_REPEAT_ON {
                    audioPlayer.currentTime = TimeInterval(self.multiRepeatSlider.value[0]) * audioPlayer.duration
                }
            }else{
                if sectionRepeatStatus == SECTION_REPEAT_ON && audioPlayer.currentTime <  TimeInterval(self.multiRepeatSlider.value[0]) * audioPlayer.duration{
                    audioPlayer.currentTime = TimeInterval(self.multiRepeatSlider.value[0]) * audioPlayer.duration
                }
            }

            let speed = speedList[speedRow] * 10
            audioPlayer.rate = Float(round(speed) / 10)
            //audioPlayer.rate = Float(round(speedList[speedRow]))
            if audioPlayer.isPlaying{
                self.PlayBtn.setImage(stopBtnLImage, for: .normal)
                //拡大縮小の処理
                musicImageTrans(v1 : self.musicArtWorkImgView, v2 : self.shadowView, type:2)
                musicImageTrans(v1 : self.musicArtWorkImgView, v2 : self.shadowView, type:1)
            }else{
                self.PlayBtn.setImage(playBtnLImage, for: .normal)
                musicImageTrans(v1 : self.musicArtWorkImgView, v2 : self.shadowView, type:0)
            }
        }
    }

    @objc func play (){
        if audioPlayer != nil {
            audioPlayer.play()
        }
    }
    @objc func stop (){
        if audioPlayer != nil {
            audioPlayer.stop()
        }
    }
    @objc func nextMusicPlayCMTapped(){
        NEXT_TAP_FLG = true
        nextMusicPlay()
    }
    @objc func prevMusicPlay(flg : Bool = true){
        if flg {
            if audioPlayer != nil {
                if audioPlayer.currentTime > 3 {
                    audioPlayer.currentTime = 0
                    return
                }
            }
        }
        if NowPlayingMusicLibraryData.nowPlaying == 0 {
            // 最初の曲を再生中だったら、最後の曲へ
            newSelectPlayNum = NowPlayingMusicLibraryData.trackData.count - 1
        }else{
            // その他は、一つ前の曲へ
            newSelectPlayNum = NowPlayingMusicLibraryData.nowPlaying - 1
        }
        if SHUFFLE_FLG {
            playMusicWrapper(playData: NowPlayingMusicLibraryData.trackDataShuffled[newSelectPlayNum])
        }else{
            playMusicWrapper(playData: NowPlayingMusicLibraryData.trackData[newSelectPlayNum])
        }
    }
    // 再生時間更新処理
    @objc func updateNowTime(tm: Timer) {
        if audioPlayer == nil {
            return
        }
        if ADApearFlg() && AD_DISPLAY_MUSICLIBRARYLIST_BANNER {
            if rewardedAd != nil {
                adRemoveBtn.isHidden = false
            }else{
                adRemoveBtn.isHidden = true
            }
        }else{
            adRemoveBtn.isHidden = true
        }
        musicNowTime.text = formatTimeString(d: audioPlayer.currentTime)
        musicProgressSlider.value = Float(audioPlayer.currentTime/audioPlayer.duration)
        if sectionRepeatStatus == SECTION_REPEAT_ON {
            if musicProgressSlider.value >= Float(multiRepeatSlider.value[1]){
                switch repeatState {
                case REPEAT_STATE_NONE:
                    if endTruckCheckRepeat(){
                        return
                    }else{
                        // !!
                        let topController = topViewController(controller: getForegroundViewController())
                        if topController is MusicPlayListViewController {
                            (topController as! MusicPlayListViewController).audioPlayerDidFinishPlaying(audioPlayer, successfully: true)

                        }else{
                            nextMusicPlay()
                        }
                    }
                case REPEAT_STATE_ONE:
                    audioPlayer.currentTime = TimeInterval(Float(multiRepeatSlider.value[0]) * Float(audioPlayer.duration))
                case REPEAT_STATE_ALL:
                    nextMusicPlay()
                default:break
                }
            }
        }
    }
    @objc func sliderChanged(_ slider: MultiSlider) {
        repeatMinTime.text = formatTimeString(d: Double(slider.value[0]) * audioPlayer.duration)
        repeatMaxTime.text = formatTimeString(d: Double(slider.value[1]) * audioPlayer.duration)
        musicProgressSlider.value = Float(Double(slider.value[0]))
        audioPlayer.currentTime = TimeInterval(musicProgressSlider.value * Float(audioPlayer.duration))
        // ここでUSERDEFAULTに設定
        if SHUFFLE_FLG {
            mMusicController.setSectionRepeatSettings(playData : NowPlayingMusicLibraryData.trackDataShuffled[newSelectPlayNum],time: multiRepeatSlider.value)
        }else{
            mMusicController.setSectionRepeatSettings(playData : NowPlayingMusicLibraryData.trackData[newSelectPlayNum],time: multiRepeatSlider.value)
        }
    }
    func nextMusicPlay(){
        if NEXT_TAP_FLG == false && repeatState == REPEAT_STATE_ONE {
            newSelectPlayNum = NowPlayingMusicLibraryData.nowPlaying
        } else {
            if NowPlayingMusicLibraryData.nowPlaying == NowPlayingMusicLibraryData.trackData.count - 1{
                // 最後の曲を再生中だったら、最初の曲へ
                newSelectPlayNum = 0
            }else{
                // その他は、一つ次の曲へ
                newSelectPlayNum = NowPlayingMusicLibraryData.nowPlaying + 1
            }
        }
        NEXT_TAP_FLG = false
        if SHUFFLE_FLG {
            playMusicWrapper(playData: NowPlayingMusicLibraryData.trackDataShuffled[newSelectPlayNum])
        }else{
            playMusicWrapper(playData: NowPlayingMusicLibraryData.trackData[newSelectPlayNum])
        }
    }
        
    /*******************************************************************
     共通処理
     *******************************************************************/
    // 区間リピート状態反映
    func setSectionRepeatStatus(){
        switch sectionRepeatStatus {
            case SECTION_REPEAT_OFF:
             repeatMaxTime.isHidden = true
             repeatMinTime.isHidden = true
             repeatSettingBtn.isHidden = true
             musicProgressSlider.isEnabled = true
             multiRepeatSlider.isHidden = true
                 if sectionRepeatEditFlg {
                     sectionRepeatEditFlg = false
                     repeatSettingBtn.setTitle(localText(key:"musiclibrary_play_section_repeat_setting"), for: .normal)
                }
             case SECTION_REPEAT_ON:
                 multiRepeatSlider.isHidden = false
                 repeatMaxTime.isHidden = false
                 repeatMinTime.isHidden = false
                 repeatSettingBtn.isHidden = false
                 sectionRepeatEditFlg = false
                 repeatSettingBtn.setTitle(localText(key:"musiclibrary_play_section_repeat_setting"), for: .normal)
                 setSectionRepeatEditStatus()
                 musicProgressSlider.value = Float(Double(multiRepeatSlider.value[0]))
                 audioPlayer.currentTime = TimeInterval(musicProgressSlider.value * Float(audioPlayer.duration))

             default:break
        }
    }
    // 区間リピート編集状態反映
     func setSectionRepeatEditStatus(){
         if sectionRepeatEditFlg {
             musicProgressSlider.isEnabled = false
             multiRepeatSlider.disabledThumbIndices = []
             multiRepeatSlider.outerTrackColor = AppColor.surface
             multiRepeatSlider.tintColor = AppColor.textSecondary
         }else{
             musicProgressSlider.isEnabled = true
             multiRepeatSlider.disabledThumbIndices = [0,1]
             multiRepeatSlider.outerTrackColor = UIColor.clear
             multiRepeatSlider.tintColor = UIColor.clear
         }
    }
    func setBGPlayCommand(){
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [])
            try session.setActive(true)
        } catch {
            //fatalError("session有効化失敗")
        }
        mMusicController.commandAllRemove()
        commandCenter.nextTrackCommand.addTarget { (commandEvent) -> MPRemoteCommandHandlerStatus in
            self.nextMusicPlayCMTapped()
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
    // 歌詞のセグメント
    func liricImgStateSegment(nowSegment : Int){
        switch nowSegment {
        case 0:
            //musicArtWorkImgView.isHidden = false
            shadowView.isHidden = false
            LyricView.isHidden = true
            mojiSizeBtn.isHidden = true
        case 1:
            //musicArtWorkImgView.isHidden = true
            shadowView.isHidden = true
            LyricView.isHidden = false
            mojiSizeBtn.isHidden = false
        default:
            print("該当無し")
        }
        lyricSegmentetion.selectedSegmentIndex = nowSegment
        LYRIC_IMG_SEGMENT_STATE = nowSegment
    }
    // リピートボタンのセグメント
    func repeatImgStateSegment(nowSegment : Int, tap:Bool = false){
        var nowSegment = nowSegment
        if tap {
            switch nowSegment {
            case REPEAT_STATE_NONE:nowSegment = REPEAT_STATE_ALL
            case REPEAT_STATE_ALL:nowSegment = REPEAT_STATE_ONE
            case REPEAT_STATE_ONE:nowSegment = REPEAT_STATE_NONE
            default:nowSegment = REPEAT_STATE_NONE
            }
        }
        switch nowSegment {
        case REPEAT_STATE_NONE:
            repeatBtn.setImage(UIImage(named: "repeat")?.withRenderingMode(.alwaysTemplate), for: .normal)
            repeatBtn.tintColor = AppColor.inactive
        case REPEAT_STATE_ALL:
            repeatBtn.setImage(UIImage(named: "repeat")?.withRenderingMode(.alwaysTemplate), for: .normal)
            repeatBtn.tintColor = AppColor.accent
        case REPEAT_STATE_ONE:
            repeatBtn.setImage(UIImage(named: "repeat1")?.withRenderingMode(.alwaysTemplate), for: .normal)
            repeatBtn.tintColor = AppColor.accent
        default:
            repeatBtn.setImage(UIImage(named: "repeat")?.withRenderingMode(.alwaysTemplate), for: .normal)
            repeatBtn.tintColor = AppColor.inactive
        }
        repeatState = nowSegment
        updateRepeatLabel()
    }
    /*******************************************************************
     広告関連の処理
     *******************************************************************/
    /*******************************************************************
     画面遷移時処理
     *******************************************************************/
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //歌詞編集画面へ
        if segue.identifier == "toMusicSetting" {
            // scanViewControllerをインスタンス化
            let secondVc = segue.destination as! scanViewController
            secondVc.editLibraryName = NowPlayingMusicLibraryData.nowPlayingLibrary
            secondVc.EDIT_FLG = true
            if SHUFFLE_FLG {
                secondVc.title = NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying].title
                secondVc.editTrackUrl = NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying].url!
                secondVc.nowLyricText = NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying].lyric
            }else{
                secondVc.title = NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying].title
                secondVc.editTrackUrl = NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying].url!
                secondVc.nowLyricText = NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying].lyric
            }
            secondVc.editShffuleFromTypeFlg = true
            secondVc.editPlayNum = NowPlayingMusicLibraryData.nowPlaying
        }
    }
    override func didMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            mMusicController.commandAllRemove()
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sectionRepeatEditFlg = false
        timer.invalidate()
    }
}

extension UIApplication {
    class func topViewController(controller: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }
    
}
