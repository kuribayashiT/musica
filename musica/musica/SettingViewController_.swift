//
//  SettingViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2017/04/19.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import MessageUI
import GoogleMobileAds
import CoreData
import AVFoundation
import Accounts
import Firebase
import AdSupport
// 広告関連
class SettingViewController_: UITableViewController ,MFMailComposeViewControllerDelegate,APVAdManagerDelegate,FADDelegate{

    @IBOutlet weak var adminBtn: UIButton!
    var size = CGSize()
    /*
     広告関連
     */
    var adLoader: AdLoader!
    var nativeAdView: NativeAdView!
    let myADView: UIView = UIView()
    var heightConstraint : NSLayoutConstraint?
    var subContentView = UIView()
    var aPVAd: UIView = UIView(frame: CGRect(x:0,y: 100,width: myAppFrameSize.width,height: myAppFrameSize.width * 11 / 16))
    var aPVAdManager: APVAdManager?

    override func viewDidLoad() {
        super.viewDidLoad()

        let manager = ASIdentifierManager.shared()
        if manager.isAdvertisingTrackingEnabled { // 広告トラッキングを許可しているのか？
            let idfaString = manager.advertisingIdentifier.uuidString
            print(idfaString)
            if idfaString == "1E79435D-5FF2-489C-9C9C-FA3EDA0254CA" {
                adminBtn.isHidden = false
            }else{
                adminBtn.isHidden = true
            }
        }else{
            adminBtn.isHidden = true
        }
//        if ADApearFlg() {
//            // 広告読み込みまでの表示設定
//            let ImageV = UIImageView()
//            ImageV.contentMode = .center
//            ImageV.frame =  CGRect(x: 0, y: 2 , width: Int(myAppFrameSize.width),height: Int(myAppFrameSize.width) * 11 / 16 )
//            ImageV.backgroundColor = UIColor.white
//            ImageV.image = UIImage(named: "homeicon_720")
//            tableView.tableFooterView = ImageV
////            tableView.contentInset.bottom = CGFloat(Int(myAppFrameSize.width) * 11 / 16)
////            tableView.contentOffset.y = CGFloat(Int(myAppFrameSize.width) * 11 / 16)
//        }
        self.tableView.estimatedRowHeight = CGFloat(CELL_ROW_HEIGT_THIN)
        self.tableView.rowHeight = UITableView.automaticDimension
        size = CGSize(width: tableView.frame.size.width, height: tableView.frame.size.width*9/16)
    }
    
    /*******************************************************************
     画面描画時の処理
     *******************************************************************/
    override func viewWillAppear(_ animated: Bool) {
        // 動画は一旦止める
        if AVPlayerViewControllerManager.shared.controller.player != nil {
            AVPlayerViewControllerManager.shared.controller.player?.pause()
        }
        super.viewWillAppear(animated)
        // navigationbarの色設定
        self.navigationController?.navigationBar.isTranslucent = false
        self.navigationController?.navigationBar.barTintColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SETTING.rawValue]
        //バーアイテムカラー
        self.navigationController?.navigationBar.tintColor = UIColor.white
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SETTING.rawValue]]
        self.navigationController!.navigationBar.tintColor = NAVIGATION_BTN_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SETTING.rawValue]
        
        // バックグラウンドでも再生できるカテゴリに設定する
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [])
        } catch  {
            // エラー処理
            fatalError("カテゴリ設定失敗")
        }
        
        // sessionのアクティブ化
        do {
            try session.setActive(true)
        } catch {
//            // audio session有効化失敗時の処理
//            // (ここではエラーとして停止している）
//            fatalError("session有効化失敗")
        }
        // 課金情報の更新
        if UserDefaults.standard.object(forKey: "kakin") == nil{
            UserDefaults.standard.set(false, forKey: "kakin")
            KAKIN_FLG = false
        }else{
            KAKIN_FLG = UserDefaults.standard.bool(forKey: "kakin")
        }
        if KAKIN_FLG {
            settingSectionTitle = settingSectionTitle_kakin
            settingSectionData = settingSectionData_kakin
            deleteAD()
        }else{
            settingSectionTitle = settingSectionTitle_mukakin
            settingSectionData = settingSectionData_mukakin
            let nibObjects = Bundle.main.loadNibNamed("UnifiedNativeAdView", owner: nil, options: nil)
            let adView = (nibObjects?.first as? NativeAdView)!
            //setAdView(adView)
        }
        tableView.reloadData()
    }
    /*　UITableViewDataSourceプロトコル */
    // セクションの個数を決める
    override func numberOfSections(in tableView: UITableView) -> Int {
        if KAKIN_FLG {
            return 3//settingSectionTitle.count
        }
        if ADApearFlg() {
            return settingSectionTitle.count
        }else{
            return settingSectionTitle.count - 1
        }
    }
    
    // セクションごとの行数を決める
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        let sectionData = settingSectionData[section]
        return sectionData.count
        
    }
    
    // セクションのタイトルを決める
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return settingSectionTitle[section]
    }
    
    func degreesToRadians(degrees: Float) -> Float {
        return degrees * Float(Double.pi) / 180.0
    }

    // セルを作る
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if settingSectionTitle[(indexPath as NSIndexPath).section] == SETTING {
            
            let sectionData = settingSectionData[(indexPath as NSIndexPath).section]
            let cellData = sectionData[(indexPath as NSIndexPath).row]
            
            switch cellData.0 {
            case SETTING_CONTENTS_NUM:
                let cell = tableView.dequeueReusableCell(withIdentifier: "SettingContents", for: indexPath) as! SettingTableViewCell
                
                if SETTING_DISPLAY_CONTENTS_NUM == 0{
                    SETTING_DISPLAY_CONTENTS_NUM = SETTING_DISPLAY_CONTENTS_NUM_ARRAY[3]
                }
                
                cell.settingContentsLabel?.text = SETTING_CONTENTS_NUM
                cell.settingValueLabel?.text = String(SETTING_DISPLAY_CONTENTS_NUM)
                return cell
                
            case SETTING_HELP_FLAG:
                let cell = tableView.dequeueReusableCell(withIdentifier: "SettingHelpContents", for: indexPath) as! SettingSwitchBtnTableViewCell
                cell.settingTitleLabel?.text = SETTING_HELP_FLAG
                cell.settingSubTitleLabel?.text = SETTING_HELP_FLAG_EXPLANATION
                cell.settingHelpSwitchBtn.isOn = HOME_HELP_BTN_DISPLAY_FLG
                return cell
            
            case SETTING_PUSH:
                let cell = tableView.dequeueReusableCell(withIdentifier: "SettingItem", for: indexPath) 
                
                cell.textLabel?.text = cellData.0
                cell.detailTextLabel?.text = cellData.1
                return cell
                
            case SETTING_DEZAIN:
                let cell = tableView.dequeueReusableCell(withIdentifier: "SettingItem", for: indexPath)

                cell.textLabel?.text = cellData.0
                cell.detailTextLabel?.text = cellData.1
                return cell
            case SETTING_CHASH_CLEAR:
                let cell = tableView.dequeueReusableCell(withIdentifier: "SettingItem", for: indexPath)
                let sectionData = settingSectionData[(indexPath as NSIndexPath).section]
                let cellData = sectionData[(indexPath as NSIndexPath).row]
                cell.accessoryType = UITableViewCell.AccessoryType.none

                cell.textLabel?.text = cellData.0
                cell.detailTextLabel?.text = cellData.1
                return cell

            default:
                let cell = tableView.dequeueReusableCell(withIdentifier: "SettingItem", for: indexPath)
                
                cell.textLabel?.text = localText(key:"setting_secret_item_title")
                cell.detailTextLabel?.text = localText(key:"setting_secret_item_body")
                return cell
            }
            
        }else if settingSectionTitle[(indexPath as NSIndexPath).section] == SPONSOR_AD{

            if AD_DISPLAY_SETTING_CONTENTS {
                // APVAdManager
                if indexPath.row == 0 {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "SettingADV", for: indexPath)
                        as! SettingADVTableViewCell
                    // 広告読み込みまでの表示設定
                    let ImageV = UIImageView()
                    ImageV.contentMode = .center
                    ImageV.frame =  CGRect(x: 0, y: 2 , width: Int(myAppFrameSize.width),height: Int(myAppFrameSize.width) * 11 / 16 )
    
                    ImageV.backgroundColor = UIColor.white
                    ImageV.image = UIImage(named: "homeicon_720")
                    cell.contentView.addSubview(myADView)
                    return cell
                }else{
                    let cell = tableView.dequeueReusableCell(withIdentifier: "SettingBanner", for: indexPath)
                        as! SettingADTableViewCell
                    // AdMobバナー広告の読み込み
                    cell.bannerView.adUnitID = ADMOB_BANNER_ADUNIT_ID
                    cell.bannerView.rootViewController = self
                    let requestBanner = Request()
                    cell.bannerView.isHidden = false
                    cell.bannerView.load(requestBanner)
                    return cell
                }
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "SettingADV", for: indexPath)
                    as! SettingADVTableViewCell
                // Imageを表示
                let imageView = UIImageView()
                imageView.contentMode = .center
                imageView.frame = CGRect(x: 0, y: 0 , width: Int(myAppFrameSize.width),height: Int(myAppFrameSize.width) * 11 / 16 )
                imageView.image = UIImage(named:"homeicon_720")!
                cell.ADView.addSubview(imageView)
                return cell
            }
        }else if settingSectionTitle[(indexPath as NSIndexPath).section] == OSUSUME{
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "SettingAppAD", for: indexPath) as! SettingAppADTableViewCell
            cell.appImage.image = UIImage(named:settingSectionApp[indexPath.row][0])
            cell.appName.text  = settingSectionApp[indexPath.row][1]
            cell.appInfo.text  = settingSectionApp[indexPath.row][2]
            fadeInRanDomAnimesion(view : cell.appImage)
            return cell
            
        }else if settingSectionTitle[(indexPath as NSIndexPath).section] == WHAT_AD{
            let cell = tableView.dequeueReusableCell(withIdentifier: "kakinCell", for: indexPath) as! SettingKakinTableViewCell
            let sectionData = settingSectionData[(indexPath as NSIndexPath).section]
            let cellData = sectionData[(indexPath as NSIndexPath).row]
            cell.title.text = cellData.0
            
            if UserDefaults.standard.object(forKey: "kakinn_tap") == nil {
                var animation: CABasicAnimation
                animation = CABasicAnimation(keyPath: "transform.rotation")
                animation.duration = 0.15
                animation.fromValue = degreesToRadians(degrees: 5.0)
                animation.toValue = degreesToRadians(degrees: -5.0)
                animation.repeatCount = Float.infinity
                animation.autoreverses = true
                cell.newIcon.isHidden = false
                cell.newIcon.layer.add(animation, forKey: "VibrateAnimationKey")
            }else{
                cell.newIcon.isHidden = true
            }
            //view.layer.add(animation, forKey: "VibrateAnimationKey")
            if ADApearFlg() == false{
                cell.accessoryType = UITableViewCell.AccessoryType.none
            }
            return cell
        }else{
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "SettingItem", for: indexPath)
            let sectionData = settingSectionData[(indexPath as NSIndexPath).section]
            let cellData = sectionData[(indexPath as NSIndexPath).row]
            
            cell.textLabel?.text = cellData.0
            cell.detailTextLabel?.text = cellData.1
            return cell
            
        }
    }
    // 必ず実装してください。
    // AmazonAdViewDelegate APVAdManagerDelegate で使う
    func viewControllerForPresentingModalView() -> UIViewController! {
        return self
    }
    func onReady(toPlayAd ad: APVAdManager!, for nativeAd: APVNativeAd!) {
        ad.showAd(for: aPVAd)
        
    }
    /*******************************************************************
     table Cell タップ時の処理
     *******************************************************************/
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sectionData = settingSectionData[indexPath.section]
        let cellData = sectionData[indexPath.row]
        
        tableView.deselectRow(at: indexPath as IndexPath, animated: true)
        
        switch cellData.0 {
        case SCANCAMERA:
            UIApplication.shared.open(URL(string: SCANCAMERA_INTRODUCTION_URL)!, options: [:], completionHandler: nil)
        case TODOLIST:
            UIApplication.shared.open(URL(string: TODOLIST_INTRODUCTION_URL)!, options: [:], completionHandler: nil)
        case MR_STICK:
            UIApplication.shared.open(URL(string: MR_STICK_INTRODUCTION_URL)!, options: [:], completionHandler: nil)
        case NANOPITA:
            UIApplication.shared.open(URL(string: NANOPITA_INTRODUCTION_URL)!, options: [:], completionHandler: nil)
        case OPEN_SOURCE_LICENSE:
            performSegue(withIdentifier: "OpenSource",sender: "")
        case APP_INFO:
            performSegue(withIdentifier: "ApliInfo",sender: "")
        case SETTING_PUSH:
            performSegue(withIdentifier: "pushSetting",sender: "")
        case SETTING_DEZAIN:
            setDezain()
        case HOW_TO_USE:
            site = HOW_TO_USE
            performSegue(withIdentifier: "HowToUse",sender: "")
        case HOMEPAGE:
            site = HOMEPAGE
            performSegue(withIdentifier: "HowToUse",sender: "")
        case SHOW_LOG:
            performSegue(withIdentifier: "showLog",sender: "")
        case SHOW_KANRI:
            performSegue(withIdentifier: "appAdmin",sender: "")
        case SETTING_CHASH_CLEAR:
            // アラートを作成
            let alert = UIAlertController(title: SETTING_CHASH_CLEAR_TITLE,message: SETTING_CHASH_CLEAR_MASAGE,preferredStyle: .alert)
            // アラートにボタンをつける
            alert.addAction(UIAlertAction(title: MESSAGE_YES, style: .default, handler: { action in
                URLCache.shared.removeAllCachedResponses()
            }))// アラートにボタンをつける
            alert.addAction(UIAlertAction(title: MESSAGE_CANCEL, style: .default, handler: { action in}))
            // アラート表示
            present(alert, animated: true, completion: nil)
        case REMOVE_AD,REMOVED_AD:
            performSegue(withIdentifier: "toADRemove",sender: "")
        case FAQ:
            performSegue(withIdentifier: "FAQ",sender: "")
            
        case IMPROVEMENT_REQUEST_SENT:
            startMailer(mailTitle :  "【" + MAIL_TITLE_IMPROVEMENT_REQUEST + "】")

        case INQUIRY_VIOLATION_REPORT:
            startMailer(mailTitle : "【" + MAIL_TITLE_INQUIRY_VIOLATION_REPORT + "】")

        case INTRODUCING_APP_FRIENDS:
            // 共有する項目
            let shareText = LINE_INTRODUCTION_MESSAGE
            let shareWebsite = NSURL(string: INTRODUCTION_URL)!
            let activityItems = [shareText, shareWebsite] as [Any]
            
            // 初期化処理
            let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
            // UIActivityViewControllerを表示
            self.present(activityVC, animated: true, completion: nil)

        case APP_REVIEW:
            UIApplication.shared.open(NSURL(string: APP_REVIEW_URL)! as URL)
        default: break
            
        }
    }

    /*******************************************************************
     メールの処理
     *******************************************************************/
    func startMailer(mailTitle : String) {
        if MFMailComposeViewController.canSendMail()==false {return}
        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let mailViewController = MFMailComposeViewController()
         let toRecipients = [ MAIL_ADDRES ]// Toの宛先、カンマ区切りの複数件対応
        mailViewController.mailComposeDelegate = self
        mailViewController.setSubject(mailTitle)
        mailViewController.setMessageBody("\n\n\n\n\n\n\n\nmusicA Ver: " + version + "\n", isHTML: false)
        mailViewController.setToRecipients(toRecipients) //Toアドレスの表示
        self.present(mailViewController, animated: true, completion: nil)
    }
    
    // メールキャンセル
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        self.dismiss(animated: true, completion: nil)
    }
    
    /*******************************************************************
     デザイン設定の処理
     *******************************************************************/
    func setDezain(){
        let actionSheet = UIAlertController(title: localText(key:"design_theme_setting_title"), message:localText(key:"design_theme_setting_body"), preferredStyle:UIAlertController.Style.actionSheet)
        let action1 = setDezainActionsheet(selectThema : NAVIGATION_COLOR_SETTINGS.DEFAULT.rawValue)
        let action2 = setDezainActionsheet(selectThema : NAVIGATION_COLOR_SETTINGS.POP.rawValue)
        let action3 = setDezainActionsheet(selectThema : NAVIGATION_COLOR_SETTINGS.WHITE_BLUE.rawValue)
        let action4 = setDezainActionsheet(selectThema : NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLACK.rawValue)
        let action5 = setDezainActionsheet(selectThema : NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLUE.rawValue)
        let action6 = setDezainActionsheet(selectThema : NAVIGATION_COLOR_SETTINGS.WHITE_DARK_RED.rawValue)
        let action7 = setDezainActionsheet(selectThema : NAVIGATION_COLOR_SETTINGS.BLACK.rawValue)
        let action8 = setDezainActionsheet(selectThema : NAVIGATION_COLOR_SETTINGS.DARK_BLUE.rawValue)
        let action9 = setDezainActionsheet(selectThema : NAVIGATION_COLOR_SETTINGS.DARK_RED.rawValue)
        let cancel = UIAlertAction(title: "キャンセル", style: UIAlertAction.Style.cancel, handler: {
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
        actionSheet.addAction(action9)
        actionSheet.addAction(cancel)
        self.present(actionSheet, animated: true, completion: nil)
    }
    
    // ActionSheetのラッパー
    func setDezainActionsheet(selectThema: Int ) -> UIAlertAction{
        var style = UIAlertAction.Style.default
        var color_thema_settings = 0
        switch selectThema {
        case NAVIGATION_COLOR_SETTINGS.DEFAULT.rawValue:
            color_thema_settings = NAVIGATION_COLOR_SETTINGS.DEFAULT.rawValue
            if NOW_COLOR_THEMA == color_thema_settings{
                style = UIAlertAction.Style.destructive
            }
        case NAVIGATION_COLOR_SETTINGS.POP.rawValue:
            color_thema_settings = NAVIGATION_COLOR_SETTINGS.POP.rawValue
            if NOW_COLOR_THEMA == color_thema_settings{
                style = UIAlertAction.Style.destructive
            }
        case NAVIGATION_COLOR_SETTINGS.WHITE_BLUE.rawValue:
            color_thema_settings = NAVIGATION_COLOR_SETTINGS.WHITE_BLUE.rawValue
            if NOW_COLOR_THEMA == color_thema_settings{
                style = UIAlertAction.Style.destructive
            }
        case NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLACK.rawValue:
            color_thema_settings = NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLACK.rawValue
            if NOW_COLOR_THEMA == color_thema_settings{
                style = UIAlertAction.Style.destructive
            }
        case NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLUE.rawValue:
            color_thema_settings = NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLUE.rawValue
            if NOW_COLOR_THEMA == color_thema_settings{
                style = UIAlertAction.Style.destructive
            }
        case NAVIGATION_COLOR_SETTINGS.WHITE_DARK_RED.rawValue:
            color_thema_settings = NAVIGATION_COLOR_SETTINGS.WHITE_DARK_RED.rawValue
            if NOW_COLOR_THEMA == color_thema_settings{
                style = UIAlertAction.Style.destructive
            }
        case NAVIGATION_COLOR_SETTINGS.BLACK.rawValue:
            color_thema_settings = NAVIGATION_COLOR_SETTINGS.BLACK.rawValue
            if NOW_COLOR_THEMA == color_thema_settings{
                style = UIAlertAction.Style.destructive
            }
        case NAVIGATION_COLOR_SETTINGS.DARK_BLUE.rawValue:
            color_thema_settings = NAVIGATION_COLOR_SETTINGS.DARK_BLUE.rawValue
            if NOW_COLOR_THEMA == color_thema_settings{
                style = UIAlertAction.Style.destructive
            }
        case NAVIGATION_COLOR_SETTINGS.DARK_RED.rawValue:
            color_thema_settings = NAVIGATION_COLOR_SETTINGS.DARK_RED.rawValue
            if NOW_COLOR_THEMA == color_thema_settings{
                style = UIAlertAction.Style.destructive
            }
        default:
            color_thema_settings = NAVIGATION_COLOR_SETTINGS.DEFAULT.rawValue
        }
        
        let action = UIAlertAction(title: String(COLOR_THEMA_NAME[color_thema_settings]), style: style, handler: {
            (action: UIAlertAction!) in
            NOW_COLOR_THEMA = color_thema_settings
            UserDefaults.standard.set(NOW_COLOR_THEMA, forKey: "colorthema")
            Analytics.setUserProperty(COLOR_THEMA_NAME[NOW_COLOR_THEMA], forName: "カラーテーマ")
            // navigationbarの色設定
            self.navigationController?.navigationBar.barTintColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SETTING.rawValue]
            //バーアイテムカラー
            self.navigationController?.navigationBar.tintColor = UIColor.white
            self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SETTING.rawValue]]
            showToastMsg(messege:localText(key:"design_theme_setting_comp"),time:2.0, tab: COLOR_THEMA.SETTING.rawValue)
        })
        
        return action
        
    }
    
    /*******************************************************************
     広告関連の処理
     *******************************************************************/
    func adViewDidFail(toLoad view: AmazonAdView!, withError: AmazonAdError!) -> Void {
        Swift.print("Ad Failed to load. Error code \(withError.errorCode): \(String(describing: withError.errorDescription))")
    }
    
    func adViewWillExpand(_ view: AmazonAdView!) -> Void {
        Swift.print("Ad will expand")
    }
    
    func adViewDidCollapse(_ view: AmazonAdView!) -> Void {
        Swift.print("Ad has collapsed")
    }
    
    // Five
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
    
    func fiveAdDidLoad(_ ad: FADAdInterface!) {
        print(FADAdInterface.self)
    }

}
