//
//  util.swift
//  musica
//
//  Created by 栗林貴大 on 2017/05/27.
//  Copyright © 2017年 K.T. All rights reserved.
//
import Foundation
import UIKit
import MediaPlayer
import AVFoundation
import CoreData
import Firebase
import GoogleMobileAds
import MultiSlider
import StoreKit

/*******************************************************************
 レイアウトのサイズ
 *******************************************************************/
let myAppFrameSize: CGSize = UIScreen.main.bounds.size
let myAppBodyHeight = getAppBodyHeght()
var BANNERHEIGHT:CGFloat = 0
func getAppBodyHeght() -> CGFloat {
    var h = UIApplication.shared.statusBarFrame.height + UINavigationController().navigationBar.frame.size.height + UITabBarController().tabBar.frame.size.height
    if #available(iOS 11.0, *) {
        let window = UIApplication.shared.keyWindow
        let topPadding = window?.safeAreaInsets.top
        let bottomPadding = window?.safeAreaInsets.bottom
        h = h + topPadding! + bottomPadding!
    }
    return myAppFrameSize.height - h
}

func getAppWithoutBodyHeght() -> CGFloat {
    var h = UIApplication.shared.statusBarFrame.height + UINavigationController().navigationBar.frame.size.height + UITabBarController().tabBar.frame.size.height
    if #available(iOS 11.0, *) {
        let window = UIApplication.shared.keyWindow
        let topPadding = window?.safeAreaInsets.top
        let bottomPadding = window?.safeAreaInsets.bottom
        h = h + topPadding! + bottomPadding!
    }
    return h
}

func getTabHeghtPlusSafeArea() -> CGFloat {
    var h = UITabBarController().tabBar.frame.size.height
    if #available(iOS 11.0, *) {
        let window = UIApplication.shared.keyWindow
        let bottomPadding = window?.safeAreaInsets.bottom
        h = h + bottomPadding!
    }
    return h
}

func getSafeAreaHeghtPlusSafeArea() -> CGFloat {
    var h : CGFloat = 0
    if #available(iOS 11.0, *) {
        let window = UIApplication.shared.keyWindow
        let bottomPadding = window?.safeAreaInsets.bottom
        h = bottomPadding!
    }
    return h
}

var selectMusicView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.light))
var selectMusicViewMakeFlg = false
let selectMusicLabel: UILabel = UILabel()
var selectBannerView = BannerView(adSize: AdSizeBanner)
var IOS13_RESIST_FLG = false
var RESIST_LIBRARY_COMPLETE_FLG = false

let selectMusicButton = UIButton(type: UIButton.ButtonType.system)
let IPHONE_5_HEIGHT = 568
let IPHONE_5S_HEIGHT = 568
let IPHONE_5C_HEIGHT = 568
let IPHONE_SE_HEIGHT = 568
let IPHONE_6_HEIGHT = 667
let IPHONE_7_HEIGHT = 667
let IPHONE_8_HEIGHT = 667
let IPHONE_6PLUS_HEIGHT = 736
let IPHONE_7PLUS_HEIGHT = 736
let IPHONE_8PLUS_HEIGHT = 736
let IPHONEX_HEIGHT  = 812
let IPHONEXR_HEIGHT  = 896
let IPHONEXSMAX_HEIGHT  = 896
/*******************************************************************
 レイアウトの色
 *******************************************************************/
extension CALayer {
    
    func setBorderIBColor(color: UIColor!) -> Void{
        self.borderColor = color.cgColor
    }
}
func setNavigationberStyle(naviBar:UINavigationBar,place:Int){
    naviBar.isTranslucent = true
    naviBar.barTintColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][place]
    //バーアイテムカラー
    naviBar.tintColor = UIColor.white
    naviBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][place]]
    naviBar.tintColor = NAVIGATION_BTN_COLOR[NOW_COLOR_THEMA][place]

}
// Dark Mode対応 - Navigation Color
func darkModeNaviWhiteUIcolor() -> UIColor{
    if #available(iOS 13.0, *) {
        let c = UIColor {
            $0.userInterfaceStyle == .dark ? UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0) : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        }
        return c
    } else {
        let c = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        return c
    }
}
// Dark Mode対応 - Icon(Black) Color
func darkModeIconBlackUIcolor() -> UIColor{
    if #available(iOS 13.0, *) {
        let c = UIColor {
            $0.userInterfaceStyle == .dark ? UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0) : UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.8)
        }
        return c
    } else {
        let c = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.8)
        return c
    }
}
// Dark Mode対応 - LabelText(Black) Color
func darkModeLabelColor() -> UIColor{
    if #available(iOS 13.0, *) {
        return UIColor.label
    } else {
        return UIColor.white
    }
}
// Dark Mode対応 - PlayGif
func darkPlayGif(vc : UIViewController) -> NSData {
    if #available(iOS 13.0, *) {
        let mode = vc.traitCollection.userInterfaceStyle
        if mode == .dark {
            return NSData(contentsOfFile: Bundle.main.path(forResource: "play006_dark",ofType:"gif")!)!
        }else{
            return NSData(contentsOfFile: Bundle.main.path(forResource: "play006",ofType:"gif")!)!
        }
    } else {
        return NSData(contentsOfFile: Bundle.main.path(forResource: "play006",ofType:"gif")!)!
    }
}
// Dark Mode対応 - darkMode 判定
func isDarkMode(vc : UIViewController) -> Bool {
    if #available(iOS 13.0, *) {
        let mode = vc.traitCollection.userInterfaceStyle
        if mode == .dark {
            return true
        }else{
            return false
        }
    } else {
        return false
    }
}

/*******************************************************************
 許諾関連
 *******************************************************************/
func showCamereAlert() {
   let alert = UIAlertController(
       title: localText(key:"plist_camera_title"),
       message: localText(key:"plist_camera_body"),
       preferredStyle: .alert)
   alert.addAction(UIAlertAction(title :localText(key:"setting"), style: .default, handler: {(action: UIAlertAction!) ->Void in
   if let url = NSURL(string: UIApplication.openSettingsURLString) {
       UIApplication.shared.open(url as URL,options: [:],completionHandler: nil)
       print("URL設定完了")}else{
       print("アラート失敗")
       }
   }
   ))
   getForegroundViewController().present(alert, animated:  true, completion:  nil)
}

func showMusicAlert() {
    let alert = UIAlertController(
        title: "This application needs to access your music library. Please allow it to access \"Meidia & Apple Music\" at Settings.",message:"",
        preferredStyle: .alert
    )
    let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: nil)
    alert.addAction(cancelAction)
    let okAction = UIAlertAction(title: "GoToSettings", style: .default) { _ in
        if let url = URL(string: UIApplication.openSettingsURLString) {
            // 設定画面をオープン
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    alert.addAction(okAction)
    getForegroundViewController().present(alert, animated: true, completion: nil)
}
/*******************************************************************
 音楽再生関連
 *******************************************************************/
// 音楽再生関数
class MusicController{
    public func playMusic(playData : TrackData,vc : UIViewController) -> String{
        // auido を再生するプレイヤーを作成する
        let audioUrl = playData.url
        var audioError:NSError?
        do {
            if audioPlayer != nil{
                audioPlayer.delegate = nil
            }
            audioPlayer = try AVAudioPlayer(contentsOf: audioUrl!)
            audioPlayer.delegate = vc as? AVAudioPlayerDelegate
            audioPlayer.enableRate = true
            audioPlayer.prepareToPlay()
            try? AVAudioSession.sharedInstance().setActive(true)
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [])
            var image = UIImage(named: "homeicon_720")
            if playData.artworkImg != nil {
                image = playData.artworkImg
            }
            defaultCenter.nowPlayingInfo = [MPMediaItemPropertyTitle: playData.title,
                                            MPMediaItemPropertyArtist: playData.artist,
                                            MPMediaItemPropertyArtwork: MPMediaItemArtwork.init(boundsSize: image!.size, requestHandler: { (size) -> UIImage in return image! }) ,
                                            MPNowPlayingInfoPropertyElapsedPlaybackTime: audioPlayer.currentTime,
                                            MPMediaItemPropertyPlaybackDuration: audioPlayer.duration,
                                            MPMediaItemPropertyLyrics: playData.lyric,
                                            MPNowPlayingInfoPropertyPlaybackRate: 1.0]
        } catch let error as NSError {
            audioError = error
            audioPlayer = nil
        }
        // エラーチェック
        if let error = audioError {
            print("Error \(error.localizedDescription)")
            return error.localizedDescription
        
        }else{
            audioPlayer.play()
            return CODE_SUCCESS
        }
    }
    // 指定された音楽が再生可能かを確認するのみのメソット
    public func checkCanPlayMusic(playData : TrackData) -> String{
        // auido を再生するプレイヤーを作成する
        let audioUrl = playData.url
        var audioError:NSError?
        var checkAudioPlayer:AVAudioPlayer!
        do {
            checkAudioPlayer = try AVAudioPlayer(contentsOf: audioUrl!)
            checkAudioPlayer.prepareToPlay()
            
        } catch let error as NSError {
            audioError = error
            checkAudioPlayer = nil
        }
        // エラーチェック
        if let error = audioError {
            print("Error \(error.localizedDescription)")
            return error.localizedDescription
            
        }else{
            return CODE_SUCCESS
        }
    }
    // 音楽データの区間リピート状態を設定
    public func setSectionRepeatSettings(playData : TrackData,time: [CGFloat]){
        if SHUFFLE_FLG {
            UserDefaults.standard.set([time[0],time[1]], forKey: playData.url!.absoluteString)
        }else{
            UserDefaults.standard.set([time[0],time[1]], forKey: playData.url!.absoluteString)
        }
    }
    // 音楽データの区間リピート設定を取得
    public func getSectionRepeatSetting(url:URL) -> [CGFloat]{
        let key = url.absoluteString
        if UserDefaults.standard.object(forKey: key) != nil{
            let repeatValue:[CGFloat] = UserDefaults.standard.array(forKey: key) as! [CGFloat]
            return repeatValue
        }else{
            return [0.0,1.0]
        }
    }
    // Command
    public func commandAllEnabled(){
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
    }
    public func commandAllRemove(){
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
    }
    
    // 歌詞文字サイズ調整処理
    public func setFontSize(textView: UITextView , btn : UIButton){
        let actionSheet = UIAlertController(title: localText(key:"moji_size_setting_title"), message: localText(key:"moji_size_setting_body"), preferredStyle:UIAlertController.Style.actionSheet)
        let action1 = setActionsheet(contentsNum : SETTING_LYRIC_SIZE_NAME_ARRAY[0], textView: textView, btn: btn)
        let action2 = setActionsheet(contentsNum : SETTING_LYRIC_SIZE_NAME_ARRAY[1], textView: textView, btn: btn)
        let action3 = setActionsheet(contentsNum : SETTING_LYRIC_SIZE_NAME_ARRAY[2], textView: textView, btn: btn)
        let action4 = setActionsheet(contentsNum : SETTING_LYRIC_SIZE_NAME_ARRAY[3], textView: textView, btn: btn)
        let action5 = setActionsheet(contentsNum : SETTING_LYRIC_SIZE_NAME_ARRAY[4], textView: textView, btn: btn)
        let action6 = setActionsheet(contentsNum : SETTING_LYRIC_SIZE_NAME_ARRAY[5], textView: textView, btn: btn)
        let cancel = UIAlertAction(title: localText(key:"btn_cancel"), style: UIAlertAction.Style.cancel, handler: {
            (action: UIAlertAction!) in
        })
        actionSheet.addAction(action1)
        actionSheet.addAction(action2)
        actionSheet.addAction(action3)
        actionSheet.addAction(action4)
        actionSheet.addAction(action5)
        actionSheet.addAction(action6)
        actionSheet.addAction(cancel)
        getForegroundViewController().present(actionSheet, animated: true, completion: nil)
    }
    // 歌詞文字サイズActionSheetのラッパー
    func setActionsheet(contentsNum: String ,textView: UITextView , btn: UIButton) -> UIAlertAction{
        var style = UIAlertAction.Style.default
        var selectSizeNum : Int = 40
        switch contentsNum {
        case SETTING_LYRIC_SIZE_NAME_ARRAY[0]:
            selectSizeNum = 0
            if SETTING_LYRIC_SIZE_NUM == selectSizeNum{
                style = UIAlertAction.Style.destructive
            }
        case SETTING_LYRIC_SIZE_NAME_ARRAY[1]:
            selectSizeNum = 1
            if SETTING_LYRIC_SIZE_NUM == selectSizeNum{
                style = UIAlertAction.Style.destructive
            }
        case SETTING_LYRIC_SIZE_NAME_ARRAY[2]:
            selectSizeNum = 2
            if SETTING_LYRIC_SIZE_NUM == selectSizeNum{
                style = UIAlertAction.Style.destructive
            }
        case SETTING_LYRIC_SIZE_NAME_ARRAY[3]:
            selectSizeNum = 3
            if SETTING_LYRIC_SIZE_NUM == selectSizeNum{
                style = UIAlertAction.Style.destructive
            }
        case SETTING_LYRIC_SIZE_NAME_ARRAY[4]:
            selectSizeNum = 4
            if SETTING_LYRIC_SIZE_NUM == selectSizeNum{
                style = UIAlertAction.Style.destructive
            }
        case SETTING_LYRIC_SIZE_NAME_ARRAY[5]:
            selectSizeNum = 5
            if SETTING_LYRIC_SIZE_NUM == selectSizeNum{
                style = UIAlertAction.Style.destructive
            }
        default:
            selectSizeNum = 3
        }
        
        let action = UIAlertAction(title: String(contentsNum), style: style, handler: {
            (action: UIAlertAction!) in
            
            SETTING_LYRIC_SIZE_NUM = selectSizeNum
            textView.font = UIFont.boldSystemFont(ofSize: CGFloat(SETTING_LYRIC_SIZE_NUM_ARRAY[SETTING_LYRIC_SIZE_NUM]))
            btn.setTitle(SETTING_LYRIC_SIZE_NAME_ARRAY[SETTING_LYRIC_SIZE_NUM], for: .normal)
            UserDefaults.standard.set(SETTING_LYRIC_SIZE_NUM, forKey: "mojisize")
            textView.isHidden = true
            textView.isHidden = false
        })
        return action
    }
}

/*******************************************************************
 共通
 *******************************************************************/
//最前面のViewControllerを取得する
func getForegroundViewController() -> UIViewController{
    var vc = UIApplication.shared.keyWindow?.rootViewController
    while let present = vc?.presentedViewController {
        vc = present
    }
    return vc!
}
func topViewController(controller: UIViewController?) -> UIViewController? {
    if let tabController = controller as? UITabBarController {
        if let selected = tabController.selectedViewController {
            return topViewController(controller: selected)
        }
    }

    if let navigationController = controller as? UINavigationController {
        return topViewController(controller: navigationController.visibleViewController)
    }

    if let presented = controller?.presentedViewController {
        return topViewController(controller: presented)
    }

    return controller
}

//再生時間のFMT
func formatTimeString(d: Double) -> String {
    var s: Int = Int(d) % 60
    var m: Int = Int((d - Double(s)) / 60 ) % 60
    let h: Int = Int((d - Double(m) - Double(s)) / 3600) % 3600
    // 1時間以上の時間表示は、カンスト表記させる
    if h > 0{
        s = 59
        m = 59
    }
    let str = String(format: "%02d:%02d",m, s)
    return str
}
/*******************************************************************
 共通アニメーション処理
 *******************************************************************/
func splashViewAnimation(mainView: UIView,splashView: UIView,logo: UIImageView){
    DispatchQueue.main.async {
        let alpha = splashView.alpha
        let transform = splashView.transform
        mainView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        splashView.transform = CGAffineTransform(scaleX: 10/11, y: 10/11)
        //少し縮小するアニメーション
        UIView.animate(withDuration: 0.2,
            delay: 0.8,
            options: UIView.AnimationOptions.curveEaseOut,
            animations: { () in
                logo.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                logo.alpha = 0.0
            }, completion: { (Bool) in
                //拡大させて、消えるアニメーション
                UIView.animate(withDuration: 0.02,
                    delay: 0.00,
                    options: UIView.AnimationOptions.curveEaseOut,
                    animations: { () in
                        splashView.alpha = 0.0
                        mainView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                    }, completion: { (Bool) in
                        splashView.isHidden = true
                        splashView.transform = transform
                        splashView.alpha = alpha
                        logo.alpha = alpha
                })
        })
    }
}
// 点滅アニメーション
func flashingAnimation(view: MultiSlider){
    DispatchQueue.main.async {
        UIView.animate(withDuration: 0.2, delay: 0.0, options: [.repeat,.autoreverse], animations: {
                view.alpha = 0.0
        }, completion: nil)
    }
}
// アイコンタップ時のアニメーション
func tappedAnimation(tappedBtn : UIButton){
    DispatchQueue.main.async {
        UIView.animate(withDuration: 0.1, animations: {
            //縮小の処理
            tappedBtn.transform = CGAffineTransform(scaleX: 3/4, y: 3/4)
        })
        UIView.animate(withDuration: 0.3, animations: {
            //拡大の処理
            tappedBtn.transform = CGAffineTransform(scaleX: 1, y: 1)
        })
    }
}
// フェードイン時のアニメーション
func fadeinAnimesion(view : UIView){
    DispatchQueue.main.async {
        view.isHidden = false
        let alpha = view.alpha
        view.alpha = 0.0
        UIView.animate(withDuration: 0.5, animations: {
            view.alpha = alpha
        })
    }
}
// フェードアウト時のアニメーション
func fadeoutAnimesion(view : UIView){
    DispatchQueue.main.async {
        let alpha = view.alpha
        let transform = view.transform
        UIView.animate(withDuration: 0.5, animations: {
            view.alpha = 0.0
        }, completion: { _ in
            view.isHidden = true
            view.transform = transform
            view.alpha = alpha
        })
    }
}
// カスタムダイアログポップアップ時のアニメーション
func dialogPopUpAnimesion(view : UIView){
    DispatchQueue.main.async {
        view.isHidden = false
        let alpha = view.alpha
        view.alpha = 0.0
        let transform = view.transform
        view.transform = CGAffineTransform(scaleX: 0, y: 0)
        view.alpha = 0.0
        UIView.animate(withDuration: 0.18, animations: {
            view.transform = CGAffineTransform(scaleX: 11/10, y: 11/10)
            view.alpha = alpha
        }, completion: { _ in
            UIView.animate(withDuration: 0.09, animations: {
                view.transform = CGAffineTransform(scaleX: 30/31, y: 30/31)
            }, completion: { _ in
                UIView.animate(withDuration: 0.06, animations: {
                    view.transform = transform
                })
            })
        })
    }
}
// カスタムダイアログポップダウン時のアニメーション
func dialogPopDownAnimesion(view : UIView){
    DispatchQueue.main.async {
        view.isHidden = false
        let alpha = view.alpha
        let transform = view.transform
        UIView.animate(withDuration: 0.24, animations: {
            view.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
            view.alpha = 0.0
        }, completion: { _ in
            view.isHidden = true
            view.transform = transform
            view.alpha = alpha
        })
    }
}
// アイコン出現時のアニメーション
func iconPopUpAnimesion(view : UIView){
    DispatchQueue.main.async {
        view.isHidden = false
        let alpha = view.alpha
        view.alpha = 0.0
        view.transform = CGAffineTransform(scaleX: 0, y: 0)
        UIView.animate(withDuration: 0.16, animations: {
            view.transform = CGAffineTransform(scaleX: 11/10, y: 11/10)
            view.alpha = alpha
        }, completion: { _ in
            UIView.animate(withDuration: 0.1, animations: {
                view.transform = CGAffineTransform(scaleX: 10/10, y: 10/10)
            })
        })
    }
}
// アイコン消滅時のアニメーション
func iconPopDownAnimesion(view : UIView){
    DispatchQueue.main.async {
        view.isHidden = false
        let alpha = view.alpha
        let transform = view.transform
        UIView.animate(withDuration: 0.16, animations: {
            view.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
            view.alpha = 0.0
        }, completion: { _ in
            view.isHidden = true
            view.transform = transform
            view.alpha = alpha
            view.isHidden = true
        })
    }
}
// ボタンタップ時のアニメーション
func tapBtnAnimesion(btn: UIButton ,image: UIImage? = nil){
    DispatchQueue.main.async {
        UIView.animate(withDuration: 0.1, animations: {
            //縮小の処理
            btn.transform = CGAffineTransform(scaleX: 1/2, y: 1/2)
        })
        if image != nil {
            btn.setImage(image, for: .normal)
        }
        UIView.animate(withDuration: 0.3, animations: {
            //拡大の処理
            btn.transform = CGAffineTransform(scaleX: 1, y: 1)
        })
    }
}
// 画像縮小アニメーション
func musicImageTrans(v1 : UIImageView, v2 : UIView, type:Int){
    DispatchQueue.main.async {
        switch type {
        case 0:
            UIView.animate(withDuration: 0.2, animations: {
                //拡大縮小の処理
                v1.transform = CGAffineTransform(scaleX: 9/10, y: 9/10)
                v2.transform = CGAffineTransform(scaleX: 7/10, y: 7/10)
            })
        case 1:
            UIView.animate(withDuration: 0.2, animations: {
                v1.transform = CGAffineTransform(scaleX: 1, y: 1)
                v2.transform = CGAffineTransform(scaleX: 1, y: 1)
            })
        case 2:
            UIView.animate(withDuration: 0.1, animations: {
                v1.transform = CGAffineTransform(scaleX: 11/10, y: 10.5/10)
                v2.transform = CGAffineTransform(scaleX: 11/10, y: 10.5/10)
            })
        case 3:
            UIView.animate(withDuration: 0.1, animations: {
                v1.transform = CGAffineTransform(scaleX: 81/100, y: 81/100)
                v2.transform = CGAffineTransform(scaleX: 7/10, y: 7/10)
            })
        default:break
        }
    }
}
// フェードイン時のランダムアニメーション
func fadeInRanDomAnimesion(view : UIView ,maxInterval: Float = 0.5){
    DispatchQueue.main.async {
        let alpha = view.alpha
        view.alpha = 0.0
        view.isHidden = false
        view.transform = CGAffineTransform(scaleX: 1/10, y: 1/10)
        let fValue = Float.random(in: 0.1 ... maxInterval)
        UIView.animate(withDuration: TimeInterval(fValue), animations: {
            view.transform = CGAffineTransform(scaleX: 21/20, y: 21/20)
            view.alpha = alpha
        }, completion: { _ in
            UIView.animate(withDuration: 0.5, animations: {
                view.transform = CGAffineTransform(scaleX: 10/10, y: 10/10)
            })
        })
    }
}
/*******************************************************************
 時間取得処理
 *******************************************************************/
func nowLogTime() -> String { /* 2018-04-30 19:33:32.265253+0900 */
    let format = DateFormatter()
    format.dateFormat = "yyyy/MM/dd HH:mm:ss.SSS"
    return format.string(from: Date())
}
/*******************************************************************
 共通トースト処理
 *******************************************************************/
// 共通トースト
func showToastMsg(messege:String,time:Double,tab:Int,setVc:UIViewController? = nil,Hposi:CGFloat = 0){
    var toastLabel = UILabel()
    let toasWidth = CGFloat(310)//myAppFrameSize.width - 32
    let height = navigationBarHeight + statusBarHeight + 4 + Hposi
    if Int(myAppFrameSize.height) == IPHONE_5_HEIGHT || Int(myAppFrameSize.height) == IPHONE_6_HEIGHT || Int(myAppFrameSize.height) == IPHONE_8PLUS_HEIGHT {
        toastLabel = UILabel(frame: CGRect(x:((getForegroundViewController().view.bounds.width-toasWidth)/2),
                                           y:height,//navigationBarHeight + statusBarHeight + 4,
                                               width:toasWidth,
                                               height:28))
    }else{
        toastLabel = UILabel(frame: CGRect(x:((getForegroundViewController().view.bounds.width-toasWidth)/2),
                                           y:height,//navigationBarHeight + statusBarHeight + 4,
                                           width:toasWidth,
                                           height:28))
    }
    var toastBGColor:UIColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][tab]
    if NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLACK.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_BLUE.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_RED.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLUE.rawValue {
        toastBGColor = NAVIGATION_BTN_COLOR[NOW_COLOR_THEMA][tab]
    }
    toastLabel.backgroundColor = toastBGColor.withAlphaComponent(0.9)
    toastLabel.textColor = UIColor.white
    toastLabel.textAlignment = .center;
    toastLabel.font = UIFont.boldSystemFont(ofSize: 12)
    toastLabel.text = messege
    toastLabel.alpha = 0.0
    toastLabel.layer.cornerRadius = 14;
    toastLabel.clipsToBounds  =  true
    getForegroundViewController().view.addSubview(toastLabel)
    DispatchQueue.main.asyncAfter(deadline: .now() , execute: {
        UIView.animate(withDuration: 0.1, delay: 0.1, options: .curveEaseOut, animations: {
            toastLabel.alpha = 1.0
        }, completion: {(isCompleted) in
            UIView.animate(withDuration: 0.3, delay: time, options: .curveEaseOut, animations: {
                toastLabel.alpha = 0.0
            }, completion: {(isCompleted) in
                toastLabel.removeFromSuperview()
            })
        })
    })
}
func showBigToastMsg(messege:String,time:Double,tab:Int,setVc:UIViewController? = nil,Hposi:CGFloat = 0){
    var toastLabel = UILabel()
    let toasWidth = CGFloat(310)//myAppFrameSize.width - 32
    let height = navigationBarHeight + statusBarHeight + 4 + Hposi
    if Int(myAppFrameSize.height) == IPHONE_5_HEIGHT || Int(myAppFrameSize.height) == IPHONE_6_HEIGHT || Int(myAppFrameSize.height) == IPHONE_8PLUS_HEIGHT {
        toastLabel = UILabel(frame: CGRect(x:((getForegroundViewController().view.bounds.width-toasWidth)/2),
                                           y:height,//navigationBarHeight + statusBarHeight + 4,
                                               width:toasWidth,
                                               height:40))
    }else{
        toastLabel = UILabel(frame: CGRect(x:((getForegroundViewController().view.bounds.width-toasWidth)/2),
                                           y:height,//navigationBarHeight + statusBarHeight + 4,
                                           width:toasWidth,
                                           height:40))
    }
    var toastBGColor:UIColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][tab]
    if NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLACK.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_BLUE.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_RED.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLUE.rawValue {
        toastBGColor = NAVIGATION_BTN_COLOR[NOW_COLOR_THEMA][tab]
    }
    toastLabel.backgroundColor = toastBGColor.withAlphaComponent(0.9)
    toastLabel.textColor = UIColor.white
    toastLabel.textAlignment = .center;
    toastLabel.font = UIFont.boldSystemFont(ofSize: 12)
    toastLabel.text = messege
    toastLabel.alpha = 0.0
    toastLabel.layer.cornerRadius = 10;
    toastLabel.clipsToBounds  =  true
    toastLabel.numberOfLines = 2
    getForegroundViewController().view.addSubview(toastLabel)
    DispatchQueue.main.asyncAfter(deadline: .now() , execute: {
        UIView.animate(withDuration: 0.1, delay: 0.1, options: .curveEaseOut, animations: {
            toastLabel.alpha = 1.0
        }, completion: {(isCompleted) in
            UIView.animate(withDuration: 0.3, delay: time, options: .curveEaseOut, animations: {
                toastLabel.alpha = 0.0
            }, completion: {(isCompleted) in
                toastLabel.removeFromSuperview()
            })
        })
    })
}
// 中央表示の小さいトースト
func showToastCenterMsg(messege:String,time:Double){
    let toastLabel = UILabel(frame: CGRect(x:((getForegroundViewController().view.bounds.width-320)/2),
                                           y:300,
                                           width:100,
                                           height:50))
    toastLabel.center = getForegroundViewController().view.center
    toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
    toastLabel.textColor = UIColor.white
    toastLabel.textAlignment = .center;
    toastLabel.font = UIFont(name: "Montserrat-Light", size: 10.0)
    toastLabel.text = messege
    toastLabel.alpha = 1.0
    toastLabel.layer.cornerRadius = 10;
    toastLabel.clipsToBounds  =  true
    getForegroundViewController().view.addSubview(toastLabel)
    DispatchQueue.main.asyncAfter(deadline: .now() + time, execute: {
        UIView.animate(withDuration: 0.3, delay: 0.1, options: .curveEaseOut, animations: {
            toastLabel.alpha = 0.0
        }, completion: {(isCompleted) in
            toastLabel.removeFromSuperview()
        })
    })
}
/*******************************************************************
 共通アラート処理
 *******************************************************************/
// 音楽再生のエラー
func showAlertMusicErrMsgOneOkBtn(title:String,messege:String){
    // アラートを作成
    let alert = UIAlertController(
        title: title,
        message: messege ,
        preferredStyle: .alert)
    // アラートにボタンをつける
    alert.addAction(UIAlertAction(title: MESSAGE_OK, style: .default))
    // アラート表示
    getForegroundViewController().present(alert, animated: true, completion: nil)
    NowPlayingMusicLibraryData.nowPlaying = -1
}

// 共通エラー
func showAlertMsgOneOkBtn(title:String,messege:String){
    // アラートを作成
    let alert = UIAlertController(
        title: title,
        message: messege ,
        preferredStyle: .alert)
    // アラートにボタンをつける
    alert.addAction(UIAlertAction(title: MESSAGE_OK, style: .default))
    // アラート表示
    getForegroundViewController().present(alert, animated: true, completion: nil)
}

// 起動時のアラートが同時に出てこないように制御
func startAlert(vc:UIViewController) -> Bool{
    let reviewAlertNum = 4
    var kakinAlertFlg = true
    var kakinAlertNum = 5
    // 課金系のフラグ
    if UserDefaults.standard.object(forKey: "kakinAlertNum") == nil{
        UserDefaults.standard.set(kakinAlertNum, forKey: "kakinAlertNum")
    }else{
        kakinAlertNum = UserDefaults.standard.integer(forKey: "kakinAlertNum")
    }
    if UserDefaults.standard.object(forKey: "kakinAlertFlg") == nil{
        UserDefaults.standard.set(kakinAlertFlg, forKey: "kakinAlertFlg")
    }else{
        kakinAlertFlg = UserDefaults.standard.bool(forKey: "kakinAlertFlg")
    }
    // レビュー誘導ダイアログ
    if SETTING_STARTUP_NUM > 0 && SETTING_STARTUP_NUM % reviewAlertNum == 0{
        if #available(iOS 10.3, *) {
            SKStoreReviewController.requestReview()
        }
        return true
    }else{
        if SETTING_STARTUP_NUM > kakinAlertNum {
            if KAKIN_FLG == false && kakinAlertFlg{
                let kakinalert = UIAlertController(title: KAKIN_TITLE,message: KAKIN_MESSAGE,preferredStyle: .alert)
                kakinalert.addAction(UIAlertAction(title: KAKIN_BTN_OK, style: .default, handler: { action in
                    vc.performSegue(withIdentifier: "appAdminfrommain",sender: "")
                    UserDefaults.standard.set(SETTING_STARTUP_NUM + 3, forKey: "kakinAlertNum")}))
                kakinalert.addAction(UIAlertAction(title: KAKIN_BTN_STAY, style: .default, handler: { action in
                    UserDefaults.standard.set(SETTING_STARTUP_NUM + 6, forKey: "kakinAlertNum")}))
                kakinalert.addAction(UIAlertAction(title: KAKIN_BTN_NO, style: .default, handler: { action in
                    UserDefaults.standard.set(false, forKey: "kakinAlertFlg")}))
                getForegroundViewController().present(kakinalert, animated: true, completion: nil)
                return true
            }
        }
    }
    return false
}

/*******************************************************************
 defalt 値
 *******************************************************************/
public func setMukakinDefault(){
    AD_DISPLAY_SEARCH_BANNER = false
    AD_DISPLAY_SEARCH_CONTENTS = false
    AD_DISPLAY_RANKING_BANNER = false
    AD_DISPLAY_RANKING_CONTENTS = false
    AD_DISPLAY_MUSIC_LYRIC_EDIT_BANNER = false
    AD_DISPLAY_MUSICLIBRARYLIST_BANNER = false
    AD_DISPLAY_MUSIC_REGISTER_ALBUM_BANNER = false
    AD_DISPLAY_MUSIC_REGISTER_TRACK_BANNER = false
    AD_DISPLAY_SETTING_CONTENTS = false
    AD_DISPLAY_FIVE_TEST_MODE = DEBUG_FLG
    AD_DISPLAY_YOUTUBE_CONTENTS = true
    AD_DISPLAY_YOUTUBE_CONTENTS_NUM = 0
    TRANS_REWARD_COUNT = 0
    MV_INTER_AD_TIME = 1000
}
public func setKakinDefault(){
    AD_DISPLAY_SEARCH_BANNER = false
    AD_DISPLAY_SEARCH_CONTENTS = false
    AD_DISPLAY_RANKING_BANNER = false
    AD_DISPLAY_RANKING_CONTENTS = false
    AD_DISPLAY_MUSIC_LYRIC_EDIT_BANNER = false
    AD_DISPLAY_MUSICLIBRARYLIST_BANNER = false
    AD_DISPLAY_MUSIC_REGISTER_ALBUM_BANNER = false
    AD_DISPLAY_MUSIC_REGISTER_TRACK_BANNER = false
    AD_DISPLAY_SETTING_CONTENTS = false
    AD_DISPLAY_FIVE_TEST_MODE = DEBUG_FLG
    AD_DISPLAY_YOUTUBE_CONTENTS = false
    AD_DISPLAY_YOUTUBE_CONTENTS_NUM = 5
    TRANS_REWARD_COUNT = 5
    MV_INTER_AD_TIME = 1000
}
/*******************************************************************
 広告
 *******************************************************************/
func removeADAlertApear(vc:UIViewController,rewardedAd: RewardedAd?, rewardHandler: @escaping () -> Void = {}){
    // アラートを作成
    var messageBody = ""
    if UserDefaults.standard.object(forKey: "review_done_flg") == nil{
        UserDefaults.standard.set(false, forKey: "review_done_flg")
        REVIEW_DONE_FLG = false
    }else{
        REVIEW_DONE_FLG = UserDefaults.standard.bool(forKey: "review_done_flg")
    }
    if UserDefaults.standard.object(forKey: "twitter_done_flg") == nil{
        UserDefaults.standard.set(false, forKey: "twitter_done_flg")
        TWITTER_DONE_FLG = false
    }else{
        TWITTER_DONE_FLG = UserDefaults.standard.bool(forKey: "twitter_done_flg")
    }
    // 選択ボタン作成
    let actionAD = UIAlertAction(title: NSLocalizedString(localText(key:"rewordad_look_AD"), comment: ""), style: UIAlertAction.Style.default, handler: {
        (action: UIAlertAction!) in
        rewardedAd?.present(from: vc, userDidEarnRewardHandler: rewardHandler)
    })
    let actionTwitter = UIAlertAction(title: NSLocalizedString(localText(key:"rewordad_look_Twitter"), comment: ""), style: UIAlertAction.Style.default, handler: {
        (action: UIAlertAction!) in
        let text = LINE_INTRODUCTION_MESSAGE
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        if let encodedText = encodedText,
            let url = URL(string: "https://twitter.com/intent/tweet?text=\(encodedText)") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            TWITTER_DONE_FLG = true
            UserDefaults.standard.set(TWITTER_DONE_FLG, forKey: "twitter_done_flg")
            let now = NSDate()
            let date1 = NSDate(timeInterval: TimeInterval(60 * 60 * Int(truncating: 3)), since: now as Date)
            UserDefaults.standard.set(date1, forKey: "ADdate")
            UserDefaults.standard.synchronize()
            deleteAD()
            vc.loadView()
            vc.viewDidLoad()
        }
    })
    let actionReview = UIAlertAction(title: NSLocalizedString(localText(key:"rewordad_look_Review"), comment: ""), style: UIAlertAction.Style.default, handler: {
        (action: UIAlertAction!) in
        guard let url = URL(string: APP_REVIEW_URL) else { return }
        UIApplication.shared.open(url)
        REVIEW_DONE_FLG = true
        UserDefaults.standard.set(REVIEW_DONE_FLG, forKey: "review_done_flg")
        let now = NSDate()
        let date1 = NSDate(timeInterval: TimeInterval(60 * 60 * Int(truncating: 3)), since: now as Date)
        UserDefaults.standard.set(date1, forKey: "ADdate")
        UserDefaults.standard.synchronize()
        deleteAD()
        vc.loadView()
        vc.viewDidLoad()
    })
    let actionPro = UIAlertAction(title: NSLocalizedString(localText(key:"rewordad_nolook"), comment: ""), style: UIAlertAction.Style.default, handler: {
        (action: UIAlertAction!) in
        let mainStoryboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let removeADPayVC = mainStoryboard.instantiateViewController(withIdentifier: "removeADPayVC")
        vc.show(removeADPayVC, sender: nil)
    })
    // メッセージ作成
    messageBody = localText(key:"rewordad_body_AD")
    if REVIEW_DONE_FLG == false{
        messageBody = messageBody + localText(key:"rewordad_body_Or")
        messageBody = messageBody + localText(key:"rewordad_body_Review")
    }
    if TWITTER_DONE_FLG == false{
        messageBody = messageBody + localText(key:"rewordad_body_Or")
        messageBody = messageBody + localText(key:"rewordad_body_Twitter")
    }
    messageBody = messageBody + localText(key:"rewordad_base")
    if REVIEW_DONE_FLG  == false{
        messageBody = messageBody + localText(key:"rewordad_body_Review_End")
    }
    
    let alert = UIAlertController(
        title: localText(key:"rewordad_title"),
        message: messageBody,
        preferredStyle: .alert)
    
    alert.addAction(actionAD)
    if TWITTER_DONE_FLG == false {
        alert.addAction(actionTwitter)
    }
    if REVIEW_DONE_FLG == false {
        alert.addAction(actionReview)
    }
    alert.addAction(actionPro)
    alert.addAction(UIAlertAction(title: MESSAGE_CANCEL, style: .default))
    vc.present(alert, animated: true, completion: nil)
}
func ADApearFlg() -> Bool{
    if KAKIN_FLG{
        deleteAD()
        return false
    }
    if UserDefaults.standard.object(forKey: "ADdate") != nil{
        let rewardDate = UserDefaults.standard.object(forKey: "ADdate") as! NSDate
        let now = NSDate()
        let span = rewardDate.timeIntervalSince(now as Date)
        if span > 0 {
            deleteAD()
            return false
        }else{
            addAD()
            return true
        }
    }else{
        addAD()
        return true
    }
}
// FIVE
public func setupFiveSDK(){
    if FIVE_INIT_FLG == true {
    }else{
        guard let config = FADConfig(appId: "47305") else { return }
        config.fiveAdFormat = Set<Int>(arrayLiteral: kFADFormatW320H180.rawValue,
                                       kFADFormatInFeed.rawValue,
                                       kFADFormatInterstitialLandscape.rawValue,
                                       kFADFormatInterstitialPortrait.rawValue,
                                       kFADFormatCustomLayout.rawValue)
        config.isTest = AD_DISPLAY_FIVE_TEST_MODE;
        FADSettings.register(config)
        FADSettings.enableLoading(true)
        FIVE_INIT_FLG = true
    }
}
//広告無効
func deleteAD(){
    // 広告表示有無
    AD_DISPLAY_SEARCH_BANNER = false
    AD_DISPLAY_SEARCH_CONTENTS = false
    AD_DISPLAY_RANKING_BANNER = false
    AD_DISPLAY_SETTING_CONTENTS = false
    AD_DISPLAY_MUSICLIBRARYLIST_BANNER = false
    AD_DISPLAY_RANKING_CONTENTS = false
    AD_DISPLAY_MUSIC_LYRIC_EDIT_BANNER = false
    AD_DISPLAY_MUSIC_REGISTER_ALBUM_BANNER = false
    AD_DISPLAY_MUSIC_REGISTER_TRACK_BANNER = false
    AD_DISPLAY_FIVE_TEST_MODE = false
    AD_DISPLAY_YOUTUBE_CONTENTS_NUM = 5
    AD_DISPLAY_YOUTUBE_CONTENTS = false
    SEARCH_RESULT_AD_INTERVAL = 0
    SEARCH_RESULT_MV_AD_INTERVAL = 0
    //SCAN_AD_INTERVAL = 0
    //TRANS_REWARD_COUNT = 0
    SEARCH_RESULT_AD_START = 0
    SEARCH_RESULT_MV_AD_START = 0
}

// UserDefaults ラッパー
func userDefaultInt(key:String) -> Int {
    if UserDefaults.standard.object(forKey: key) == nil{
        return 0
    }else{
        return UserDefaults.standard.integer(forKey: key)
    }
}
func userDefaultBool(key:String) -> Bool {
    if UserDefaults.standard.object(forKey: key) == nil{
        return false
    }else{
        return UserDefaults.standard.bool(forKey: key)
    }
}
func userDefaultString(key:String) -> String {
    if UserDefaults.standard.object(forKey: key) == nil{
        return ""
    }else{
        return UserDefaults.standard.string(forKey: key)!
    }
}
//広告無効
func addAD(){
    // 広告表示有無
    AD_DISPLAY_SEARCH_BANNER = userDefaultBool(key:"ad_display_search_banner")
//    AD_DISPLAY_SEARCH_CONTENTS = userDefaultBool(key:"ad_display_search_contents")
    AD_DISPLAY_RANKING_BANNER = userDefaultBool(key:"ad_display_ranking_banner")
    AD_DISPLAY_SETTING_CONTENTS = userDefaultBool(key:"ad_display_setting_contents")
    AD_DISPLAY_MUSICLIBRARYLIST_BANNER = userDefaultBool(key:"ad_display_musiclibrary_contents")
    AD_DISPLAY_RANKING_CONTENTS = userDefaultBool(key:"ad_display_ranking_contents")
    AD_DISPLAY_MUSIC_LYRIC_EDIT_BANNER = userDefaultBool(key:"ad_display_music_lyric_edit_banner")
    AD_DISPLAY_MUSIC_REGISTER_ALBUM_BANNER = userDefaultBool(key:"ad_display_music_register_album_banner")
    AD_DISPLAY_MUSIC_REGISTER_TRACK_BANNER = userDefaultBool(key:"ad_display_music_register_track_banner")
    AD_DISPLAY_FIVE_TEST_MODE = userDefaultBool(key:"ad_display_five_test_mode")
    AD_DISPLAY_YOUTUBE_CONTENTS_NUM = userDefaultInt(key:"ad_display_youtube_contents")
    MUSIC_LIBRARY_AD_INTERVAL = userDefaultInt(key:"music_library_interstitial_interval")
    SEARCH_MV_AD_INTERVAL = userDefaultInt(key:"search_MV_AD_interstitial_interval")
    SEARCH_RECOMMEND_AD = userDefaultBool(key:"search_recommend_AD")
    if AD_DISPLAY_YOUTUBE_CONTENTS_NUM == 0{
        AD_DISPLAY_YOUTUBE_CONTENTS = false
    }else{
        AD_DISPLAY_YOUTUBE_CONTENTS = true
    }
    SEARCH_RESULT_AD_INTERVAL = userDefaultInt(key:"search_result_AD_interval")
    SEARCH_RESULT_MV_AD_INTERVAL = userDefaultInt(key:"search_result_MV_AD_interval")
    SEARCH_RESULT_AD_START = userDefaultInt(key:"search_result_AD_start")
    SEARCH_RESULT_MV_AD_START = userDefaultInt(key:"search_result_MV_AD_start")
}
/*******************************************************************
 Admob
*******************************************************************/
func custumLoadBannerAd(bannerView: BannerView!,setBannerView:UIView) {
  // Step 2 - Determine the view width to use for the ad width.
  let frame = { () -> CGRect in
    // Here safe area is taken into account, hence the view frame is used
    // after the view has been laid out.
    if #available(iOS 11.0, *) {
      return setBannerView.frame.inset(by: setBannerView.safeAreaInsets)
    } else {
      return setBannerView.frame
    }
  }()
  bannerView.translatesAutoresizingMaskIntoConstraints = true
  let viewWidth = frame.size.width
  bannerView.adSize = currentOrientationAnchoredAdaptiveBanner(width: viewWidth)
  BANNERHEIGHT = bannerView.adSize.size.height
  bannerView.load(Request())
  bannerView.translatesAutoresizingMaskIntoConstraints = false
}

/*******************************************************************
 Push機能
*******************************************************************/
var RANKING_PUSH_RECIEVE_FLG = false
// Push登録
func setLocalPush(){
    deleteLocalPush(pushID:LOCAL_PUSH_RANKING_ID)
    // ローカル通知のの内容
    let content = UNMutableNotificationContent()
    content.sound = UNNotificationSound.default
    content.title = localText(key:"local_push_ranking_title")
    content.body = localText(key:"local_push_ranking_body")
    content.badge = 1
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "ja_JP") // TODO クラッシュ対策。取り急ぎ、日本時間のみ
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let pushDate = dateFormatter.date(from: "2020-01-19 18:32:00")
    // 繰り返し設定
    var notificationTime = DateComponents()
    notificationTime = Calendar(identifier: .gregorian).dateComponents([.weekday, .hour, .minute], from: pushDate!)

    // ローカル通知リクエストを作成
    let trigger = UNCalendarNotificationTrigger(dateMatching: notificationTime, repeats: true)
    let request = UNNotificationRequest(identifier: LOCAL_PUSH_RANKING_ID, content: content, trigger: trigger)
    // ローカル通知リクエストを登録
    UNUserNotificationCenter.current().add(request){ (error : Error?) in
        if let error = error {
            print(error.localizedDescription)
        }
    }
}
// Push削除
func deleteLocalPush(pushID:String){
    // 通知の削除
    //print("通知データ = ",UIApplication.shared.scheduledLocalNotifications)
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [pushID])
    //print("通知データ = ",UIApplication.shared.scheduledLocalNotifications)
    
}
/*******************************************************************
 アプリ再起動
 *******************************************************************/
func softwareReset() {
    let notification = Notification(name: MySoftwareRestartNotification)
    NotificationCenter.default.post(notification)
}
extension Array where Element: Equatable {
    mutating func remove(value: Element) {
        if let i = self.index(of: value) {
            self.remove(at: i)
        }
    }
}
/*******************************************************************
 多言語化
 *******************************************************************/
func localText(key:String) -> String {
    return NSLocalizedString(key, comment: "")
}
/*******************************************************************
 Firebase realtimedatabase関連
 *******************************************************************/
func setOkiniiriData(videoId:String,categoryID:Int,title:String,imageUrl:String,time:String){
    var ref: DatabaseReference!
    ref = Database.database().reference()
    let day = toStringWithDay()
    let local = localText(key:"firebase_local_country")
    // Firebase非対応文字列が無いかチェック
    if checkFBCharactor(checkText:videoId) || videoId == "" {
        return
    }
    // 動画を登録
    ref.child("OKINIIRI").child(local).child(day).child(videoId).observeSingleEvent(of: .value, with: { (snapshot) in
        // すでに登録済み？
        if snapshot.hasChild("regist_num"){
            let value = snapshot.value as? NSDictionary
            let _regist_num = value?["regist_num"] as? Int ?? 0
            let regist_num = Int(_regist_num) + 1
            // ・・・だったらregist_numをインクリメントして更新
            ref.child("OKINIIRI").child(local).child(day).child(videoId).setValue([
                "regist_num": regist_num,
                "can_play_flg":true,
                "type":1,
                "categoryID":categoryID,
                "title":title,
                "time":time,
                "imageUrl":imageUrl,
                ])
        }else{
            ref.child("OKINIIRI").child(local).child(day).child(videoId).setValue([
                "regist_num": 1,
                "can_play_flg":true,
                "type":1,
                "categoryID":categoryID,
                "title":title,
                "imageUrl":imageUrl,
                ])
        }
    })
}

func setSearchWordData(searchWord:String){
//    if DEBUG_FLG {
//        return
//    }
    var ref: DatabaseReference!
    ref = Database.database().reference()
    let day = toStringWithDay()
    let local = localText(key:"firebase_local_country")
    // Firebase非対応文字列が無いかチェック
    if checkFBCharactor(checkText:searchWord) || searchWord == "" {
        return
    }
    // 検索ワードを登録
    ref.child("SEARCH").child(local).child(day).child(searchWord).observeSingleEvent(of: .value, with: { (snapshot) in
        // すでに登録済み？
        if snapshot.hasChild("regist_num"){
            let value = snapshot.value as? NSDictionary
            let _regist_num = value?["regist_num"] as? Int ?? 0
            let regist_num = Int(_regist_num) + 1
            // ・・・だったらregist_numをインクリメントして更新
            ref.child("SEARCH").child(local).child(day).child(searchWord).setValue([
                "regist_num": regist_num
                ])
        }else{
            ref.child("SEARCH").child(local).child(day).child(searchWord).setValue([
                "regist_num": 1,
                ])
        }
    })
}
func setLibraryNameData(name:String,truck_num:Int){
//    if DEBUG_FLG {
//        return
//    }
    var ref: DatabaseReference!
    ref = Database.database().reference()
    let day = toStringWithDay()
    let local = localText(key:"firebase_local_country")
    // Firebase非対応文字列が無いかチェック
    if checkFBCharactor(checkText:name) || name == "" {
        return
    }
    ref.child("LIBRARYNAME").child(local).child(day).child(name).observeSingleEvent(of: .value, with: { (snapshot) in
        // すでに登録済み？
        if snapshot.hasChild("regist_num"){
            let value = snapshot.value as? NSDictionary
            let _regist_num = value?["regist_num"] as? Int ?? 0
            let regist_num = Int(_regist_num) + 1
            // ・・・だったらregist_numをインクリメントして更新
            ref.child("LIBRARYNAME").child(local).child(day).child(name).setValue([
                "regist_num": regist_num,
                "truck_num": truck_num
                ])
        }else{
            ref.child("LIBRARYNAME").child(local).child(day).child(name).setValue([
                "regist_num": 1,
                "truck_num": truck_num
                ])
        }
    })
}
// Firebase非対応文字列が無いかチェック
func checkFBCharactor(checkText : String ) -> Bool{
    // 不正文字列が無いかチェック
    if checkText == ""||(checkText.contains(".")) || (checkText.contains("#")) || (checkText.contains("$")) ||
        (checkText.contains("[")) || (checkText.contains("]")){
        return true
    }else{
        return false
    }
}
func toStringWithDay() -> String {
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone.current
    formatter.locale = Locale.current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
}
func _toStringWithDay(prev : Int) -> String {
    var calendar = Calendar.current
    let _day = calendar.date(byAdding: .day, value: -prev, to: calendar.startOfDay(for: Date()))
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone.current
    formatter.locale = Locale.current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: _day!)
}
// recommend
var recomendWardList:[String] = []
var recomendMvList:[candidateMV] = []
var recommendWardHiddenFlg = false
var recommendMvHiddenFlg = false
func judgeDisplayRecommendWard(flg:Bool) -> Bool {
    if recommendWardHiddenFlg  == false {
        return flg
    }
    return true
}
func judgeDisplayRecommendMV(flg:Bool) -> Bool {
    if recommendMvHiddenFlg == false{
        return flg
    }
    return true
}

//構造体を定義する。
struct candidateWd {
    var title : String? = ""
    var num : Int = 0
    var checkFlg : Bool = false
}
struct candidateMV {
    var title : String? = ""
    var imgUrl : String? = ""
    var videoID : String? = ""
    var num : Int = 0
    var time : String? = ""
    var checkFlg : Bool = false
}
func getRecommendWard(collect : UICollectionView? = nil){
    var ref: DatabaseReference!
    ref = Database.database().reference()
    ref.child("SEARCH").child(localText(key:"ranking_default_settings_")).child("NOW_RECOMMEND").observeSingleEvent(of: .value, with: { (snapshot) in
        recomendWardList = []
        let value = snapshot.value as? NSDictionary
        if value != nil {
            for _v in value! {
                recomendWardList.append((_v.key as! String))
                recommendWardHiddenFlg = true
            }
            if collect != nil{
                collect?.reloadData()
            }
        }
    }) { (error) in
        print(error.localizedDescription)
    }
}
func getRecommendMV(collect : UICollectionView? = nil){
    let local = localText(key:"youtube_local_country")
    let youtubeChartUrl =  "https://www.googleapis.com/youtube/v3/videos?key=\(API_KEY)&chart=mostPopular&maxResults=30&regionCode=\(local)&videoCategoryId=10&part=snippet,statistics,contentDetails&"
    let session = URLSession.shared
    var jsonResult : NSDictionary = NSDictionary()
    let task = session.dataTask(with: URLRequest(url: URL(string: youtubeChartUrl)!), completionHandler: {
        (data, response, error) in
        do {
            if data == nil {
                recommendMvHiddenFlg = false
                return
            }
            if let _jsonResult: NSDictionary = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? NSDictionary {
                jsonResult = _jsonResult
            }
            recomendMvList = []
            if jsonResult.object(forKey: "items") == nil {
                recommendMvHiddenFlg = false
                return
            }
            let value = (jsonResult.object(forKey: "items") as? [[String: Any]])! //((jsonResult.object(forKey: "items") as! NSArray) as [AnyObject]) as [AnyObject]
            for (index, _v) in value.enumerated() {
                var cd = candidateMV()
                cd.videoID = _v["id"]! as? String ?? ""
                //let snippet = _v.object(forKey: "snippet") as! NSDictionary
                let snippet = _v["snippet"] as! [String: Any]
                cd.title = snippet["title"] as? String ?? ""
                let imgObj = snippet["thumbnails"] as! NSDictionary
                let imgUrl = imgObj["medium"] as! NSDictionary
                cd.imgUrl = imgUrl["url"] as? String ?? ""
                cd.time = snippet["url"] as? String ?? ""
                let contentDetails: NSDictionary = _v["contentDetails"] as! NSDictionary
                var duration: String = contentDetails.object(forKey: "duration") as! String
                let iso8601DurationPattern = "^PT(?:(\\d+)H)?(?:(\\d+)M)?(?:(\\d+)S)?$"
                let iso8601DurationRegex = try! NSRegularExpression(pattern: iso8601DurationPattern, options: [])
                if let match = iso8601DurationRegex.firstMatch(in: duration, options: [], range: NSRange(0..<duration.utf16.count)) {
                    let hRange = match.range(at: 1)
                    let hStr = (hRange.location != NSNotFound) ? (duration as NSString).substring(with: hRange) : ""
                    let hInt = Int(hStr) ?? 0
                    let mRange = match.range(at: 2)
                    let mStr = (mRange.location != NSNotFound) ? (duration as NSString).substring(with: mRange) : ""
                    let mInt = Int(mStr) ?? 0
                    let sRange = match.range(at: 3)
                    let sStr = (sRange.location != NSNotFound) ? (duration as NSString).substring(with: sRange) : ""
                    let sInt = Int(sStr) ?? 0
                    let durationFormatted =
                        (hInt == 0)
                            ? String(format: "%02d:%02d", mInt, sInt)
                            : String(format: "%02d:%02d:%02d", hInt, mInt, sInt)
                    duration = durationFormatted
                } else {
                    duration = "??:??"
                }
                cd.time = duration
                recomendMvList.append(cd)
                recommendMvHiddenFlg = true
            }
        } catch {
            recommendMvHiddenFlg = false
        }
    })
    task.resume()
}
/*******************************************************************
 RemoteConfig
 *******************************************************************/
import Firebase
func setUpRemoteconfig(vc:HomeAreaViewController!){
    // アプリバージョン情報の取得
    //let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    //vc.remoteConfig.activate() // これでパラメータを取得できる
    print("base_version   :" + (vc?.remoteConfig["base_version"].stringValue)!)
    print("latest_version :" + (vc?.remoteConfig["latest_version"].stringValue)!)

    // 広告表示有無　-> Userdefaultに保存
    UserDefaults.standard.set((vc?.remoteConfig["ad_display_search_banner"].boolValue)!, forKey: "ad_display_search_banner")
 //   UserDefaults.standard.set((vc?.remoteConfig["ad_display_search_contents"].boolValue)!, forKey: "ad_display_search_contents")
    UserDefaults.standard.set((vc?.remoteConfig["ad_display_ranking_banner"].boolValue)!, forKey: "ad_display_ranking_banner")
    UserDefaults.standard.set((vc?.remoteConfig["ad_display_setting_contents"].boolValue)!, forKey: "ad_display_setting_contents")
    UserDefaults.standard.set((vc?.remoteConfig["ad_display_musiclibrary_contents"].boolValue)!, forKey: "ad_display_musiclibrary_contents")
    UserDefaults.standard.set((vc?.remoteConfig["ad_display_ranking_contents"].boolValue)!, forKey: "ad_display_ranking_contentsad_display_ranking_contents")
    UserDefaults.standard.set((vc?.remoteConfig["ad_display_music_lyric_edit_banner"].boolValue)!, forKey: "ad_display_music_lyric_edit_banner")
    UserDefaults.standard.set((vc?.remoteConfig["ad_display_music_register_album_banner"].boolValue)!, forKey: "ad_display_music_register_album_banner")
    UserDefaults.standard.set((vc?.remoteConfig["ad_display_music_register_track_banner"].boolValue)!, forKey: "ad_display_music_register_track_banner")
    UserDefaults.standard.set(Int(truncating: (vc?.remoteConfig["ad_display_youtube_contents"].numberValue)!), forKey: "ad_display_youtube_contents")
    UserDefaults.standard.set(Int(truncating: (vc?.remoteConfig["ad_display_youtube_contents"].numberValue)!), forKey: "ad_display_youtube_contents")
    UserDefaults.standard.set(Int(truncating: (vc?.remoteConfig["search_result_AD_interval"].numberValue)!), forKey: "search_result_AD_interval")
    UserDefaults.standard.set(Int(truncating: (vc?.remoteConfig["search_result_MV_AD_interval"].numberValue)!), forKey: "search_result_MV_AD_interval")
    UserDefaults.standard.set(Int(truncating: (vc?.remoteConfig["ad_display_five_test_mode"].numberValue)!), forKey: "ad_display_five_test_mode")
    UserDefaults.standard.set(Int(truncating: (vc?.remoteConfig["search_result_AD_start"].numberValue)!), forKey: "search_result_AD_start")
    UserDefaults.standard.set(Int(truncating: (vc?.remoteConfig["search_result_MV_AD_start"].numberValue)!), forKey: "search_result_MV_AD_start")
    UserDefaults.standard.set(Int(truncating: (vc?.remoteConfig["music_library_interstitial_interval"].numberValue)!), forKey: "music_library_interstitial_interval")
    UserDefaults.standard.set(Int(truncating: (vc?.remoteConfig["search_MV_AD_interstitial_interval"].numberValue)!), forKey: "search_MV_AD_interstitial_interval")
    
    
    UserDefaults.standard.set((vc?.remoteConfig["youtube_api_key_Select"].stringValue)!, forKey: "youtube_api_key_Select")
    UserDefaults.standard.set((vc?.remoteConfig["youtube_api_key"].stringValue)!, forKey: "youtube_api_key")
    UserDefaults.standard.set((vc?.remoteConfig["youtube_api_key_GrB"].stringValue)!, forKey: "youtube_api_key_GrB")
    UserDefaults.standard.set((vc?.remoteConfig["youtube_api_key_GrC"].stringValue)!, forKey: "youtube_api_key_GrC")
    UserDefaults.standard.set((vc?.remoteConfig["youtube_api_key_GrD"].stringValue)!, forKey: "youtube_api_key_GrD")
    UserDefaults.standard.set((vc?.remoteConfig["youtube_api_key_GrE"].stringValue)!, forKey: "youtube_api_key_GrE")
    UserDefaults.standard.set((vc?.remoteConfig["youtube_api_key_second"].stringValue)!, forKey: "youtube_api_key_second")
    UserDefaults.standard.set((vc?.remoteConfig["youtube_api_key_change_flg"].boolValue)!, forKey: "youtube_api_key_change_flg")
    UserDefaults.standard.set((vc?.remoteConfig["search_recommend_AD"].boolValue)!, forKey: "search_recommend_AD")
    // TODO test
    switch userDefaultInt(key:"youtube_api_key_Select") {
    case 0:
        API_KEY = userDefaultString(key:"youtube_api_key")
    case 1:
        API_KEY = userDefaultString(key:"youtube_api_key_GrB")
    case 2:
        API_KEY = userDefaultString(key:"youtube_api_key_GrC")
    case 3:
        API_KEY = userDefaultString(key:"youtube_api_key_GrD")
    case 4:
        API_KEY = userDefaultString(key:"youtube_api_key_GrE")
    default:
        API_KEY = userDefaultString(key:"youtube_api_key")
    }
    API_KEY_YOBI = userDefaultString(key:"youtube_api_key_second")
    API_KEY_CHANGE_FLG = userDefaultBool(key:"youtube_api_key_change_flg")
    
    addAD()
    UserDefaults.standard.set((vc?.remoteConfig["youtube_mode"].boolValue)!, forKey: "youtube_mode")
    if userDefaultInt(key:"youtube_mode") == 0 {
        YOUTUBE_PLAYER_FLG = false
    }else if userDefaultInt(key:"youtube_mode") == 1 {
        YOUTUBE_PLAYER_FLG = true
    }else{
        YOUTUBE_PLAYER_FLG = false
    }
    SCAN_AD_INTERVAL = Int(truncating: (vc?.remoteConfig["scan_ad_interval"].numberValue)!)
    RANKING_AD_INTERVAL = Int(truncating: (vc?.remoteConfig["ad_display_rankingInter_interval"].numberValue)!)
    LINE_INTRODUCTION_MESSAGE = (vc?.remoteConfig["line_introduction_message"].stringValue)!
    MAX_TEXT_NUM = Int(truncating: (vc?.remoteConfig["max_text_trans_num"].numberValue)!)

//    // アプリバージョンの比較
//    let versionArray = version.components(separatedBy:".")
//    let baseVersionArray = vc?.remoteConfig["base_version"].stringValue?.components(separatedBy:".")
//    let latestVersionArray = vc?.remoteConfig["latest_version"].stringValue?.components(separatedBy:".")
//    var UpdateFlg = false
//    var ForceUpdateFlg = false
//
//    if (vc?.remoteConfig["review_flg"].boolValue)!{
//        settingSectionAD = [(APP_REVIEW,""),(INTRODUCING_APP_FRIENDS,"")]
//    }else{
//        settingSectionAD = [(INTRODUCING_APP_FRIENDS,"")]
//    }
//    // キャンセル済みのバージョンがないか確認
//    var latest_version_canceledArray : [String] = []
//
//    let appDelegate: AppDelegate = UIApplication.shared.delegate as! AppDelegate
//    let viewContext:NSManagedObjectContext = appDelegate.managedObjectContext
//    let request: NSFetchRequest<SettingStatus> = SettingStatus.fetchRequest()
//    // 読み出し
//    do {
//        let fetchResults = try viewContext.fetch(request)
//        print(fetchResults)
//        if (!fetchResults.isEmpty) {
//            for result: AnyObject in fetchResults {
//                print(result)
//                //latest_version_canceled = (result.value(forKey: "latestCancelVersion") as? String)!
//                latest_version_canceledArray = (result.value(forKey: "latestCancelVersion") as? String)!.components(separatedBy:".")
//            }
//        } else {
//            latest_version_canceledArray = versionArray
//        }
//    } catch {
//        latest_version_canceledArray = versionArray
//    }
//    if baseVersionArray![0] != "" || latestVersionArray![0] != "" {
//        for (index, element) in versionArray.enumerated() {
//            if Int((baseVersionArray?[index])!)! > Int(element)! {
//                ForceUpdateFlg = true
//                break
//            } else if Int((baseVersionArray?[index])!)! == Int(element)! {
//                continue
//            } else {
//                break
//            }
//        }
//        for (index, element) in latest_version_canceledArray.enumerated() {
//            if Int((latestVersionArray?[index])!)! > Int(element)! {
//                UpdateFlg = true
//                break
//            } else if Int((latestVersionArray?[index])!)! == Int(element)! {
//                continue
//            } else {
//                break
//            }
//        }
//
//    }
//
//    // 強制アップデートダイアログ判定
//    if ForceUpdateFlg {
//        // アラートを作成
//        let alert = UIAlertController(title: FORCE_UPDATE_DIALOG_TITLE,message: FORCE_UPDATE_DIALOG_MESSAGE,preferredStyle: .alert)
//        // アラートにボタンをつける
//        alert.addAction(UIAlertAction(title: MESSAGE_YES, style: .default, handler: { action in
//            UIApplication.shared.open(URL(string: INTRODUCTION_URL)!, options: [:], completionHandler: nil)
//        }))
//        // アラート表示
//        vc?.present(alert, animated: true, completion: nil)
//    }
//
//    // 任意アップデートダイアログ判定
//    if ForceUpdateFlg == false && UpdateFlg {
//        // アラートを作成
//        let alert = UIAlertController(
//            title: OPTIONAL_UPDATE_DIALOG_TITLE,
//            message: OPTIONAL_UPDATE_DIALOG_MESSAGE,
//            preferredStyle: .alert)
//
//        // アラートにボタンをつける
//        alert.addAction(UIAlertAction(title: MESSAGE_YES, style: .default, handler: { action in
//            UIApplication.shared.open(URL(string: INTRODUCTION_URL)!, options: [:], completionHandler: nil)
//        }))
//
//        alert.addAction(UIAlertAction(title: MESSAGE_NO, style: .default, handler: { action in
//            do {
//                let saveContext:NSManagedObjectContext = appDelegate.managedObjectContext
//                let fetchResults = try saveContext.fetch(request)
//                if (!fetchResults.isEmpty) {
//                    for result: AnyObject in fetchResults {
//                        print(result)
//                        let record = result as! NSManagedObject
//                        record.setValue(vc?.remoteConfig["latest_version"].stringValue, forKey: "latestCancelVersion")
//                    }
//                }else {
//                    let SettingStatus = NSEntityDescription.entity(forEntityName: "SettingStatus", in: saveContext)
//                    let newRecord = NSManagedObject(entity: SettingStatus!, insertInto: saveContext)
//                    newRecord.setValue(vc?.remoteConfig["latest_version"].stringValue, forKey: "latestCancelVersion")
//                }
//
//                try saveContext.save()
//            } catch {
//
//            }
//
//        }))
//        // アラート表示
//        getForegroundViewController().present(alert, animated: true, completion: nil)
//    }
    //Settingのデータを読み込む
//    SETTING_DISPLAY_CONTENTS_NUM = SETTING_DISPLAY_CONTENTS_NUM_ARRAY[3]
    //let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
}

@objcMembers class Utilities: NSObject {
    static let shared = Utilities()
    func displayError(_ error: NSError, originViewController: UIViewController) {
        OperationQueue.main.addOperation {
            originViewController.dismiss(animated: true) {
                let alert = UIAlertController(title: NSLocalizedString("Error", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil))
                originViewController.present(alert, animated: true, completion: nil)
            }
        }
    }
}
