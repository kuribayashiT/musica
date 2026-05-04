//
//  SettingViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2020/07/30.
//  Copyright © 2020 K.T. All rights reserved.
//

import UIKit
import MessageUI
import GoogleMobileAds
import CoreData
import AVFoundation
import Accounts
import Firebase
import AdSupport

class SettingViewController: UIViewController , UITableViewDataSource, UITableViewDelegate , MFMailComposeViewControllerDelegate,APVAdManagerDelegate,FADDelegate{
    var size = CGSize()
    /*
     広告関連
     */
    @IBOutlet weak var adView: UIView!
    @IBOutlet weak var adminBtn: UIButton!
    var adLoader: AdLoader!
    var nativeAdView: NativeAdView!
    var nativeAdIsLoaded = false
    let myADView: UIView = UIView()
    var heightConstraint : NSLayoutConstraint?
    var subContentView = UIView()
    var aPVAd: UIView = UIView(frame: CGRect(x:0,y: 100,width: myAppFrameSize.width,height: myAppFrameSize.width * 11 / 16))
    var aPVAdManager: APVAdManager?
    
    @IBOutlet weak var table: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
        let manager = ASIdentifierManager.shared()
        if manager.isAdvertisingTrackingEnabled { // 広告トラッキングを許可しているのか？
            let idfaString = manager.advertisingIdentifier.uuidString
            dlog(idfaString)
            if idfaString == "1E79435D-5FF2-489C-9C9C-FA3EDA0254CA" {
                adminBtn.isHidden = false
            } else {
                navigationItem.rightBarButtonItem = nil
            }
        } else {
            navigationItem.rightBarButtonItem = nil
        }
        table.estimatedRowHeight = 52
        table.rowHeight = UITableView.automaticDimension
        // 固定オーバーレイ広告は非表示（テーブル内に移動）
        adView.isHidden = true
        table.delegate = self
        table.dataSource = self

        // ラージタイトルが動作するようにテーブルを view.topAnchor まで拡張する
        // （Storyboard のフレームはナビゲーションバー下から始まっているため）
        table.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: view.topAnchor),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        table.contentInsetAdjustmentBehavior = .automatic
        // grouped スタイルが先頭セクションに自動挿入するパディングを除去
        if #available(iOS 15.0, *) {
            table.sectionHeaderTopPadding = 0
        }

        size = CGSize(width: table.bounds.width, height: table.bounds.width * 9 / 16)

        // ラージタイトル（viewDidLoad で先に確定させておく）
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        title = localText(key: "tab_options")
        // デザインシステム適用
        applyDesignSystem()
    }
    
    /*******************************************************************
     画面描画時の処理
     *******************************************************************/
    override func viewWillAppear(_ animated: Bool) {
        // 動画は一旦止める
        if AVPlayerViewControllerManager.shared.controller.player != nil {
            AVPlayerViewControllerManager.shared.controller.player?.pause()
        }
        selectMusicView.isHidden = true
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        // navigationbarの色設定（AppColor ベース）
        self.navigationController?.navigationBar.isTranslucent = true
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: AppColor.textPrimary]
        appearance.largeTitleTextAttributes = [NSAttributedString.Key.foregroundColor: AppColor.textPrimary]
        self.navigationController?.navigationBar.standardAppearance = appearance
        self.navigationController?.navigationBar.scrollEdgeAppearance = appearance
        self.navigationController?.navigationBar.compactAppearance = appearance
        self.navigationController?.navigationBar.tintColor = AppColor.accent
        
        // バックグラウンドでも再生できるカテゴリに設定する
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(true)
            try session.setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [])
        } catch  {
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
            setAdView(adView)
        }
        table.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async {
            self.table.setContentOffset(
                CGPoint(x: 0, y: -self.table.adjustedContentInset.top),
                animated: false
            )
        }
    }

    /*******************************************************************
     UITableViewDataSourceプロトコル
     *******************************************************************/
    // セクションの個数を決める
    func numberOfSections(in tableView: UITableView) -> Int {
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
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        let sectionData = settingSectionData[section]
        return sectionData.count
        
    }
    
    // セクションのタイトルを決める
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil  // カスタムヘッダー使用
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let isOsusume = settingSectionTitle[section] == OSUSUME

        // おすすめアプリセクション: ネイティブ広告 + ラベルを一体化
        if isOsusume && nativeAdIsLoaded {
            let adW = myAppFrameSize.width
            let adH = adW * 11 / 16
            let container = UIView(frame: CGRect(x: 0, y: 0, width: adW, height: adH + 38))
            container.backgroundColor = .clear
            nativeAdView.frame = CGRect(x: 0, y: 0, width: adW, height: adH)
            container.addSubview(nativeAdView)
            let label = UILabel(frame: CGRect(x: 20, y: adH + 6, width: adW - 40, height: 26))
            label.text = OSUSUME.uppercased()
            label.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
            label.textColor = AppColor.textSecondary
            container.addSubview(label)
            return container
        }

        let container = UIView()
        container.backgroundColor = .clear
        let label = UILabel()
        label.text = settingSectionTitle[section].uppercased()
        label.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = AppColor.textSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
        ])
        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if settingSectionTitle[section] == OSUSUME && nativeAdIsLoaded {
            return myAppFrameSize.width * 11 / 16 + 38
        }
        return 38
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // バナー広告セルはシンプルに
        if cell.reuseIdentifier == "SettingBanner" || cell.reuseIdentifier == "SettingADV" {
            cell.backgroundColor = AppColor.surface
            cell.selectionStyle = .none
            return
        }

        cell.backgroundColor = AppColor.surface
        cell.textLabel?.textColor = AppColor.textPrimary
        cell.detailTextLabel?.textColor = AppColor.textSecondary

        // カード角丸
        let rowCount = tableView.numberOfRows(inSection: indexPath.section)
        let isFirst = indexPath.row == 0
        let isLast  = indexPath.row == rowCount - 1

        cell.layer.cornerRadius = 0
        cell.layer.maskedCorners = []

        if isFirst && isLast {
            cell.layer.cornerRadius = 12
            cell.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner,
                                         .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        } else if isFirst {
            cell.layer.cornerRadius = 12
            cell.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        } else if isLast {
            cell.layer.cornerRadius = 12
            cell.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
        cell.layer.masksToBounds = true

        // 選択ハイライト
        let sel = UIView()
        sel.backgroundColor = AppColor.accentMuted
        cell.selectedBackgroundView = sel

        // SettingItem にカラーアイコンバッジ
        if cell.reuseIdentifier == "SettingItem", let title = cell.textLabel?.text {
            let (symbol, color) = iconConfig(for: title)
            cell.imageView?.image = iconBadgeImage(symbol: symbol, color: color)
            cell.imageView?.layer.cornerRadius = 7
            cell.imageView?.clipsToBounds = true
        }

        // kakinCell: 独自レイアウトのため badge を手動 subview として追加
        if let kakinCell = cell as? SettingKakinTableViewCell {
            let badgeTag = 9997
            if kakinCell.contentView.viewWithTag(badgeTag) == nil {
                let badgeView = UIImageView()
                badgeView.tag = badgeTag
                badgeView.layer.cornerRadius = 7
                badgeView.clipsToBounds = true
                badgeView.translatesAutoresizingMaskIntoConstraints = false
                kakinCell.contentView.addSubview(badgeView)
                NSLayoutConstraint.activate([
                    badgeView.leadingAnchor.constraint(equalTo: kakinCell.contentView.leadingAnchor, constant: 16),
                    badgeView.centerYAnchor.constraint(equalTo: kakinCell.contentView.centerYAnchor),
                    badgeView.widthAnchor.constraint(equalToConstant: 30),
                    badgeView.heightAnchor.constraint(equalToConstant: 30),
                ])
                // title ラベルの leading 制約を badge 分ずらす
                if let lc = kakinCell.contentView.constraints.first(where: {
                    ($0.firstItem as? UIView) == kakinCell.title && $0.firstAttribute == .leading
                }) { lc.constant = 62 }
            }
            if let badgeView = kakinCell.contentView.viewWithTag(badgeTag) as? UIImageView {
                let (symbol, color) = iconConfig(for: REMOVE_AD)
                badgeView.image = iconBadgeImage(symbol: symbol, color: color)
            }
        }

        // SettingContents / SettingHelpContents: 左側アクセントバー
        if cell.reuseIdentifier == "SettingContents" || cell.reuseIdentifier == "SettingHelpContents" {
            let barTag = 8888
            if cell.contentView.viewWithTag(barTag) == nil {
                let bar = UIView()
                bar.tag = barTag
                bar.backgroundColor = AppColor.accent
                bar.layer.cornerRadius = 2
                bar.translatesAutoresizingMaskIntoConstraints = false
                cell.contentView.addSubview(bar)
                NSLayoutConstraint.activate([
                    bar.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                    bar.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                    bar.widthAnchor.constraint(equalToConstant: 4),
                    bar.heightAnchor.constraint(equalToConstant: 22),
                ])
            }
        }
    }

    // MARK: - Design System

    private func applyDesignSystem() {
        view.backgroundColor = AppColor.background
        table.backgroundColor = AppColor.background
        table.separatorColor = AppColor.separator
        table.separatorInset = UIEdgeInsets(top: 0, left: 62, bottom: 0, right: 0)
        table.tableFooterView = UIView()
    }

    private func iconConfig(for title: String) -> (String, UIColor) {
        switch title {
        case REMOVE_AD, REMOVED_AD:
            return ("star.fill",                   AppColor.accent)
        case SETTING_PUSH:
            return ("bell.fill",                   UIColor.systemBlue)
        case SETTING_DEZAIN:
            return ("paintpalette.fill",           UIColor.systemPurple)
        case SETTING_CHASH_CLEAR:
            return ("trash.fill",                  UIColor.systemRed)
        case HOW_TO_USE:
            return ("book.fill",                   UIColor(hex: "#34C759"))
        case HOMEPAGE:
            return ("globe",                       UIColor.systemBlue)
        case INTRODUCING_APP_FRIENDS:
            return ("square.and.arrow.up",         UIColor.systemOrange)
        case IMPROVEMENT_REQUEST_SENT:
            return ("lightbulb.fill",              UIColor(hex: "#FF9500"))
        case INQUIRY_VIOLATION_REPORT:
            return ("envelope.fill",               UIColor.systemBlue)
        case APP_INFO:
            return ("info.circle.fill",            UIColor.systemGray)
        case FAQ:
            return ("questionmark.circle.fill",    UIColor.systemTeal)
        case OPEN_SOURCE_LICENSE:
            return ("doc.text.fill",               UIColor.systemGray)
        case SHOW_LOG:
            return ("terminal.fill",               UIColor.systemGray)
        case SHOW_KANRI:
            return ("wrench.and.screwdriver.fill", UIColor.systemGray)
        default:
            return ("gearshape.fill",              UIColor.systemGray)
        }
    }

    private func iconBadgeImage(symbol: String, color: UIColor) -> UIImage? {
        let badgeSize = CGSize(width: 30, height: 30)
        let renderer  = UIGraphicsImageRenderer(size: badgeSize)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: badgeSize))
            let cfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            guard let img = UIImage(systemName: symbol, withConfiguration: cfg)?
                    .withTintColor(.white, renderingMode: .alwaysOriginal) else { return }
            let origin = CGPoint(
                x: (badgeSize.width  - img.size.width)  / 2,
                y: (badgeSize.height - img.size.height) / 2
            )
            img.draw(at: origin)
        }
    }

    func degreesToRadians(degrees: Float) -> Float {
        return degrees * Float(Double.pi) / 180.0
    }
    // tableフッターの高さを返却
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    // tableフッターを返却
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    // セルを作る
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
    
                    ImageV.backgroundColor = AppColor.surface
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
            // TODO IconはURLから取得　cell.appImage.sd_setImage(with: imgUrl as URL)
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
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
    
    
//    func parseRecommendAppData(){
//        let str = """
//            [{"name":"John","age":37},{"name":"Tim"}]
//            """
//
//        struct ParseError: Error {}
//        do {
//            guard let data = json.data(using: .utf8) else {
//                 throw ParseError()
//             }
//            let json = try JSONSerialization.jsonObject(with: data)
//            guard let rows = json as? [[String:Any]] else {
//                throw ParseError()
//            }
//            for row in rows {
//                // ここでAddしていく
//                let name = row["name"] ?? ""
//                let age = row["age"] ?? 0
//                dlog("\(name) is \(age)")
//            }
//        } catch {
//            dlog("error")
//        }
//    }
    /*******************************************************************
     広告関連の処理
     *******************************************************************/
    func adViewDidFail(toLoad view: AmazonAdView!, withError: AmazonAdError!) -> Void {
        dlog("Ad Failed to load. Error code \(withError.errorCode): \(String(describing: withError.errorDescription))")
    }
    
    func adViewWillExpand(_ view: AmazonAdView!) -> Void {
        dlog("Ad will expand")
    }
    
    func adViewDidCollapse(_ view: AmazonAdView!) -> Void {
        dlog("Ad has collapsed")
    }
    
    // Five
    var fadDelegate:FADDelegate!
    func fiveAdDidReplay(_ ad: FADAdInterface!) {
        dlog(FADAdInterface.self)
    }
    
    func fiveAdDidViewThrough(_ ad: FADAdInterface!) {
        dlog(FADAdInterface.self)
        
    }
    
    func fiveAdDidResume(_ ad: FADAdInterface!) {
        dlog(FADAdInterface.self)
    }
    
    func fiveAdDidPause(_ ad: FADAdInterface!) {
        dlog(FADAdInterface.self)
    }
    func fiveAdDidStart(_ ad: FADAdInterface!) {
        dlog(FADAdInterface.self)
    }
    
    func fiveAdDidClose(_ ad: FADAdInterface!) {
        dlog(FADAdInterface.self)
    }
    
    
    
    func fiveAdDidClick(_ ad: FADAdInterface!) {
        dlog(FADAdInterface.self)
    }
    
    
    
    func fiveAd(_ ad: FADAdInterface!, didFailedToReceiveAdWithError errorCode: FADErrorCode) {
        dlog(errorCode)
    }
    
    func fiveAdDidLoad(_ ad: FADAdInterface!) {
        dlog(FADAdInterface.self)
    }

}
