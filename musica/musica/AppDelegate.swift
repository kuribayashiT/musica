//
//  AppDelegate.swift
//  musica
//
//  Created by 栗林貴大 on 2017/04/16.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import CoreData
import Firebase
import UserNotifications
import SwiftyStoreKit
import FirebaseMessaging
import AppTrackingTransparency
import AdSupport
import GoogleMobileAds

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate{

    var window: UIWindow?
    
    let gcmMessageIDKey = "gcm.message_id"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        Messaging.messaging().delegate = self as MessagingDelegate
        // 起動回数取得
        if UserDefaults.standard.object(forKey: "startUpCount") == nil{
            UserDefaults.standard.set(SETTING_STARTUP_NUM, forKey: "startUpCount")
        }else{
            SETTING_STARTUP_NUM = UserDefaults.standard.integer(forKey: "startUpCount") + 1
            UserDefaults.standard.set(SETTING_STARTUP_NUM, forKey: "startUpCount")
        }
        MobileAds.shared.isApplicationMuted = true
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [TEST_DEVICE_iPHPNEX]
        if UIApplication.shared.applicationIconBadgeNumber > 0 {
            RANKING_PUSH_RECIEVE_FLG = true
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        // テスト用のAPIキーに切り替え
//        let manager = ASIdentifierManager.shared()
//        if manager.isAdvertisingTrackingEnabled { // 広告トラッキングを許可しているのか？
//            let idfaString = manager.advertisingIdentifier.uuidString
//            print(idfaString)
////            if idfaString == "1E79435D-5FF2-489C-9C9C-FA3EDA0254CA" {
////                API_KEY = API_KEY_TEST
////                API_KEY_TOP = API_KEY_TEST
////            }
//        }

        /*******************************************************************
         課金状態の取得
         *******************************************************************/
        SwiftyStoreKit.completeTransactions(atomically: true) { purchases in
            for purchase in purchases {
                switch purchase.transaction.transactionState {
                case .purchased, .restored:
                    KAKIN_FLG = true
                    UserDefaults.standard.set(KAKIN_FLG, forKey: "kakin")
                    if purchase.needsFinishTransaction {
                        // Deliver content from server, then:
                        SwiftyStoreKit.finishTransaction(purchase.transaction)
                    }
                // Unlock content
                case .failed, .purchasing, .deferred:
                    KAKIN_FLG = false
                    UserDefaults.standard.set(KAKIN_FLG, forKey: "kakin")
                    // break// do nothing
                }
            }
        }
        SwiftyStoreKit.retrieveProductsInfo(["kuriFCTmusica"]) { result in
            if let product = result.retrievedProducts.first {
                //未購入の場合
                KAKINPLICE_PLICE = product.localizedDescription
            } else {
               //購入済みの場合
            }
        }

        /*******************************************************************
         UserDefaultから設定値の取得
         *******************************************************************/
        // "firstLaunch"をキーに、Bool型の値を保持する
        let dict = ["firstLaunch": true]
        
        // "firstLaunch"をキーに、Bool型の値を保持する
        let dict_02 = ["firstLaunch_Flg": true]
        // デフォルト値登録
        // ※すでに値が更新されていた場合は、更新後の値のままになる
        UserDefaults.standard.register(defaults: dict_02)
        UserDefaults.standard.register(defaults: dict)
        
        // "firstLaunch"に紐づく値がtrueなら(=初回起動)、値をfalseに更新して処理を行う
        if UserDefaults.standard.bool(forKey: "firstLaunch") {
            UserDefaults.standard.set(false, forKey: "firstLaunch")
            self.initMasters()
        }else{
            /*******************************************************************
             Firebase Push設定
             *******************************************************************/
            // Firebase Push
            UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]){
                (granted, _) in
                if granted{
                    UNUserNotificationCenter.current().delegate = self
                    setLocalPush()
                }else{
                    deleteLocalPush(pushID:LOCAL_PUSH_RANKING_ID)
                }
            }
        }
        // 文字サイズ設定
        if UserDefaults.standard.object(forKey: "mojisize") != nil{
            SETTING_LYRIC_SIZE_NUM = UserDefaults.standard.integer(forKey: "mojisize")
        }
        // UserDefaultsを使って動画再生回数をカウントする
        if UserDefaults.standard.object(forKey: "mvCount") == nil{
            UserDefaults.standard.set(MV_PLAY_NUM, forKey: "mvCount")
        }else{
            MV_PLAY_NUM = UserDefaults.standard.integer(forKey: "mvCount")
        }
        // UserDefaultsを使ってスキャン回数をカウントする
        if UserDefaults.standard.object(forKey: "scanCount") == nil{
            UserDefaults.standard.set(SCAN_USE_NUM, forKey: "scanCount")
        }else{
            SCAN_USE_NUM = UserDefaults.standard.integer(forKey: "scanCount")
        }
        // UserDefaultsを使って翻訳回数をカウントする
        if UserDefaults.standard.object(forKey: "trans_Count") == nil{
            UserDefaults.standard.set(TRANS_USE_NUM, forKey: "trans_Count")
        }else{
            TRANS_USE_NUM = UserDefaults.standard.integer(forKey: "trans_Count")
        }
        // UserDefaultsを使ってランキング視聴回数をカウントする
        if UserDefaults.standard.object(forKey: "rankingLookCount") == nil{
            UserDefaults.standard.set(RANKING_LOOK_NUM, forKey: "rankingLookCount")
        }else{
            RANKING_LOOK_NUM = UserDefaults.standard.integer(forKey: "rankingLookCount")
        }
        // 動画再生回数をUserPropatyにSet
        Analytics.setUserProperty(String(MV_PLAY_NUM), forName: "動画再生回数")
        Analytics.setUserProperty(String(SCAN_USE_NUM), forName: "スキャン回数")
        Analytics.setUserProperty(String(TRANS_USE_NUM), forName: "翻訳回数")

        // カラーテーマ設定（AppTheme で一元管理）
        AppTheme.restoreFromUserDefaults()

        if UserDefaults.standard.object(forKey: "transCount") == nil{
            UserDefaults.standard.set(TRANS_REWARD_COUNT, forKey: "transCount")
        }else{
            TRANS_REWARD_COUNT  = UserDefaults.standard.integer(forKey: "transCount")
        }

        // UserDefaultsを使って課金状況を判定する
        if UserDefaults.standard.object(forKey: "kakin") == nil{
            UserDefaults.standard.set(false, forKey: "kakin")
            KAKIN_FLG = false
        }else{
            KAKIN_FLG = UserDefaults.standard.bool(forKey: "kakin")
        }
        // レビューフラグ
        if UserDefaults.standard.object(forKey: "review_done_flg") == nil{
            UserDefaults.standard.set(false, forKey: "review_done_flg")
            REVIEW_DONE_FLG = false
        }else{
            REVIEW_DONE_FLG = UserDefaults.standard.bool(forKey: "review_done_flg")
        }
        /*******************************************************************
         課金状態から設定値の取得
         *******************************************************************/
        if DEBUG_FLG {
            //APPVAMDOR_AD_TEST_PUBID = APPVAMDOR_AD_TEST_PUBID
            APPVAMDOR_AD_PUBID_TOP = APPVAMDOR_AD_TEST_PUBID
            APPVAMDOR_AD_PUBID_SETTING = APPVAMDOR_AD_TEST_PUBID
            APPVAMDOR_AD_PUBID_CAMERA = APPVAMDOR_AD_TEST_PUBID
            APPVAMDOR_AD_PUBID_RANKING = APPVAMDOR_AD_TEST_PUBID
            APPVAMDOR_AD_PUBID_SEARCH = APPVAMDOR_AD_TEST_PUBID
            ADMOB_REWARD_TRANS = ADMOB_REWARD_TRANS_test
            ADMOB_INTERSTITIAL_MV = ADMOB_INTERSTITIAL_SCAN_OR_TRANS_test
            ADMOB_INTERSTITIAL_SCAN_OR_TRANS = ADMOB_INTERSTITIAL_SCAN_OR_TRANS_test
            ADMOB_REWARD_AD = ADMOB_REWARD_AD_test
            ADMOB_INTERSTITIAL_CUSTUM_LIBRARY = ADMOB_INTERSTITIAL_SCAN_OR_TRANS_test
            ADMOB_INTERSTITIAL_LIBRARY = ADMOB_INTERSTITIAL_SCAN_OR_TRANS_test
            ADMOB_INTERSTITIAL_SEARCH = ADMOB_INTERSTITIAL_SCAN_OR_TRANS_test
            ADMOB_INTERSTITIAL_RANKING = ADMOB_INTERSTITIAL_SCAN_OR_TRANS_test
            ADMOB_NATIVE_ADVANCE_SEARCH_CONTENTS = ADMOB_NATIVE_ADVANCE_TEST
            ADMOB_NATIVE_ADVANCE_SEARCH_RECOMMEND = ADMOB_NATIVE_ADVANCE_TEST
            ADMOB_NATIVE_ADVANCE_SETTINGS = ADMOB_NATIVE_ADVANCE_TEST
            ADMOB_NATIVE_ADVANCE_RANKING = ADMOB_NATIVE_ADVANCE_TEST
            ADMOB_NATIVE_ADVANCE_RANKING_CONTENTS = ADMOB_NATIVE_ADVANCE_TEST
            ADMOB_NATIVE_ADVANCE = ADMOB_NATIVE_ADVANCE_TEST
            ADMOB_BANNER_ADUNIT_ID = ADMOB_BANNER_ADUNIT_ID_TEST
            settingSectionData = settingSectionData_dev
            settingSectionTitle = settingSectionTitle_mukakin
        }
        // 課金時の設定
        if KAKIN_FLG {
            settingSectionData = settingSectionData_kakin
            settingSectionTitle = settingSectionTitle_kakin
            deleteAD()
        }else{
            settingSectionData = settingSectionData_mukakin
            settingSectionTitle = settingSectionTitle_mukakin
            addAD()
        }
        // シミュレータ用デモデータのシード（実機では何もしない）
        DemoDataSeeder.seedIfNeeded(appDelegate: self)

        // CoreDataのマイグレーション
        var _: NSPersistentStoreCoordinator = {
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: (managedObjectModel))
            let url = applicationDocumentsDirectory.appendingPathComponent("SingleViewCoreData.sqlite")
            let failureReason = "There was an error creating or loading the application's saved data."

            let options = [NSMigratePersistentStoresAutomaticallyOption: true,NSInferMappingModelAutomaticallyOption: true]

            do {
                try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: options)
            } catch {
                // Report any error we got.
                var dict = [String: AnyObject]()
                dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data" as AnyObject
                dict[NSLocalizedFailureReasonErrorKey] = failureReason as AnyObject

                dict[NSUnderlyingErrorKey] = error as NSError
                let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
                NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
                abort()
            }

            return coordinator
        }()
        return true
    }
    
    private func showRequestTrackingAuthorizationAlert() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization(completionHandler: { status in
                switch status {
                case .authorized:
                    print("🎉")
                    //IDFA取得
                    print("IDFA: \(ASIdentifierManager.shared().advertisingIdentifier)")
                case .denied, .restricted, .notDetermined:
                    print("😭")
                @unknown default:
                    fatalError()
                }
            })
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("APNs token retrieved: \(deviceToken)")
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        if #available(iOS 14, *) {
            switch ATTrackingManager.trackingAuthorizationStatus {
            case .authorized:
                print("Allow Tracking")
                print("IDFA: \(ASIdentifierManager.shared().advertisingIdentifier)")
            case .denied:
                print("😭拒否")
            case .restricted:
                print("🥺制限")
            case .notDetermined:
                showRequestTrackingAuthorizationAlert()
            }
        } else {// iOS14未満
            if ASIdentifierManager.shared().isAdvertisingTrackingEnabled {
                print("Allow Tracking")
                print("IDFA: \(ASIdentifierManager.shared().advertisingIdentifier)")
            } else {
                print("🥺制限")
            }
        }
        if UIApplication.shared.applicationIconBadgeNumber > 0 {
            RANKING_PUSH_RECIEVE_FLG = true
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    // MARK: - Core Data stack
    
    lazy var applicationDocumentsDirectory: NSURL = {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1] as NSURL
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        let modelURL = Bundle.main.url(forResource: "RegistMusicLibraryModel", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // Create the coordinator and store
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.appendingPathComponent("SingleViewCoreData.sqlite")
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
        } catch {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data" as AnyObject?
            dict[NSLocalizedFailureReasonErrorKey] = failureReason as AnyObject?
            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            abort()
        }
        
        return coordinator
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()
    @available(iOS 10.0, *)
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "RegistMusicLibraryModel")
        
        //let container = NSPersistentContainer(name: "coredataTest")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                //fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    func saveContext () {
        if #available(iOS 10.0, *) {
            let context = persistentContainer.viewContext
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    _ = error as NSError
                    //fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
                }
            }
        } else {
            if managedObjectContext.hasChanges {
                do {
                    try managedObjectContext.save()
                } catch {
                    let nserror = error as NSError
                    NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
                    abort()
                }
            }
        }
    }

    func initMasters() {
        // 登録する
        let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
        let MusicLibraryContext:NSManagedObjectContext = appDelegate.managedObjectContext
        let MusicLibraryEntity = NSEntityDescription.entity(forEntityName: "MusicLibraryModel", in: MusicLibraryContext)
        let musicLibraryModel = NSManagedObject(entity:MusicLibraryEntity!,insertInto:MusicLibraryContext) as! MusicLibraryModel
        
        musicLibraryModel.musicLibraryName = MV_LIST_NAME
        musicLibraryModel.trackNum = Int16(0)
        musicLibraryModel.creationDate = Date() as Date 
        musicLibraryModel.iconName = "star"
        musicLibraryModel.icomColorName = colorChoicesNameArray[0]
        
        // 登録されているMusicLibrary数を取得
        let context:NSManagedObjectContext = appDelegate.managedObjectContext
        let fetchRequest:NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
        let fetchData = try! context.fetch(fetchRequest)
        if(!fetchData.isEmpty){
            
            musicLibraryModel.indicatoryNum = Int16(fetchData.count)
        }else{
            musicLibraryModel.indicatoryNum = 0
        }
        
        do{
            try MusicLibraryContext.save()
            
        }catch{
            print(error)
            let dict = ["firstLaunch": false]
            // 次回起動時にもう一回やり直す為の値登録
            let userDefault = UserDefaults.standard
            userDefault.register(defaults: dict)
            return
        }
    }

    //サイレントで通知を受け取った場合
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void){
        //通知を受け取った時の処理
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        // Print full message.
        print(userInfo)
    }
    // [END receive_message]

    // スキーム起動対応
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        //URLの確認なので無くてもOK
        if url.host == nil{
            return true
        }
        
        //リクエストされたURLの中からhostの値を取得して変数に代入
        let urlHost : String = (url.host as String?)!
        
        //遷移させたいViewControllerが格納されているStoryBoardファイルを指定
        let mainStoryboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        
        //urlHostにnextが入っていた場合はmainstoryboard内のnextViewControllerのviewを表示する
        if(urlHost == "ranking"){
            let resultVC: ITuneRankingViewController = mainStoryboard.instantiateViewController(withIdentifier: "ITuneRankingViewController") as! ITuneRankingViewController
            self.window?.rootViewController = resultVC
        }
        self.window?.makeKeyAndVisible()
        return true
    }
}

// [START ios_10_message_handling]
@available(iOS 10, *)
extension AppDelegate : UNUserNotificationCenterDelegate {
    
    //アプリ起動時に通知を受け取った時に通る
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        
        UIApplication.shared.applicationIconBadgeNumber = 1
        RANKING_PUSH_RECIEVE_FLG = true
        // messageIDを出力
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
            if let aps = userInfo["aps"] as? NSDictionary {
                if let alertMessage = aps["alert"] as? String {
                    
                    // アラートを作成
                    let alert = UIAlertController(
                        title: PUSH_TITLE,
                        message: alertMessage,
                        preferredStyle: .alert)
                    
                    // アラートにボタンをつける
                    alert.addAction(UIAlertAction(title: MESSAGE_OK, style: .default, handler: { action in
                        
                    }))
                    // アラート表示
                    getForegroundViewController().present(alert, animated: true, completion: nil)
                }
            }
            
        }
        
        // 優先する通知オプションの変更を行う場合は設定する
        completionHandler([])
    }
    
    //受け取った通知を開いた時に通る
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        RANKING_PUSH_RECIEVE_FLG = true
        START_APP_TAB = 1
        print(userInfo)
        
        completionHandler()
    }
}

// [END ios_10_message_handling]
extension AppDelegate : MessagingDelegate {
    // [START refresh_token]
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")
        let token = Messaging.messaging().fcmToken
        print("FCM token: \(token ?? "")")
        // TODO: If necessary send token to application server.
        // Note: This callback is fired at each app startup and whenever a new token is generated.
    }
    // [END refresh_token]
    // [START ios_10_data_message]
    // Receive data messages on iOS 10+ directly from FCM (bypassing APNs) when the app is in the foreground.
    // To enable direct data messages, you can set Messaging.messaging().shouldEstablishDirectChannel to true.
//    func messaging(_ messaging: Messaging, didReceive remoteMessage: MessagingRemoteMessage) {
//        print("Received data message: \(remoteMessage.appData)")
//    }
    // [END ios_10_data_message]
}

