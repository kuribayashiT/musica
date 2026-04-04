//
//  YoutubeVideoViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2017/06/05.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import WebKit
import GoogleMobileAds
import CoreData
import ReachabilitySwift
import AVFoundation
import MediaPlayer

public let ReachabilityChangedNotification = NSNotification.Name("ReachabilityChangedNotification")
class YoutubeVideoViewController: UIViewController, AVAudioPlayerDelegate ,WKNavigationDelegate ,WKUIDelegate{

    @IBOutlet weak var videoView: UIView!

    @IBOutlet weak var youtubeBtnHideView: UIView!
    // Youtube再生
    @IBOutlet weak var waitView: UIVisualEffectView!
    var youtubeVideoWebView = WKWebView()
    let reachability = Reachability()!
    // お気に入り動画に追加ボタン
    @IBOutlet weak var addOKINIIRIBtn: UIButton!
    var addFlg : Bool = true
    var itemsInfoArray = [AnyObject]()
    private var _observers = [NSKeyValueObservation]()
    //遷移元のView
    var fromView = COLOR_THEMA.HOME
    var color = UIColor.lightGray
    var nowYoutubeVideoID : String = ""
    var youtubeVideoTitle : String = ""
    var youtubeVideoThumbnailUrl : String = ""
    var youtubeVideoTime : String = ""
    override func viewDidLoad() {
        super.viewDidLoad()
        // ステータスバーの高さを取得する
        let STATUSBARHEIGHT = UIApplication.shared.statusBarFrame.size.height
        // ナビゲーションバーの高さを取得する
        let NAVIGATIONBARHEIGHTNAVIGATIONBARHEIGH = self.navigationController?.navigationBar.frame.size.height
        // タブバーの高さを取得する
        let TABBARHEIGHT = self.tabBarController?.tabBar.frame.size.height
        let disableCalloutScriptString = "document.documentElement.style.webkitTouchCallout='none';"
        let disableCalloutScript = WKUserScript(source: disableCalloutScriptString, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        let controller = WKUserContentController()
        controller.addUserScript(disableCalloutScript)
        let viewConfiguration = WKWebViewConfiguration()
        viewConfiguration.userContentController = controller //上記の操作禁止を反映
        youtubeVideoWebView = WKWebView(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.height - STATUSBARHEIGHT - NAVIGATIONBARHEIGHTNAVIGATIONBARHEIGH! - TABBARHEIGHT!), configuration: viewConfiguration)
        youtubeVideoWebView.navigationDelegate = self
        youtubeVideoWebView.uiDelegate = self
        youtubeVideoWebView.allowsBackForwardNavigationGestures = true
        youtubeVideoWebView.isOpaque = false
        youtubeVideoWebView.backgroundColor = videoView.backgroundColor
        youtubeVideoWebView.scrollView.backgroundColor = videoView.backgroundColor
        self.videoView.addSubview(self.youtubeVideoWebView)
        let edgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        // 上の余白部分
        youtubeVideoWebView.scrollView.contentInset = edgeInsets
        youtubeVideoWebView.scrollView.bounces = true
        if audioPlayer != nil {
            if (audioPlayer.isPlaying){
                // 一旦音楽は止める
                audioPlayer.stop()
            }
        }
                
        let playVideoUrl = "https://www.youtube.com/watch?v=" + nowYoutubeVideoID
        
        // Do any additional setup after loading the view.
        let favoriteURL = NSURL(string: playVideoUrl)
        let urlRequest = URLRequest(url: favoriteURL! as URL)
        youtubeVideoWebView.load(urlRequest)
                
        waitView.isHidden = false
        _observers.append(youtubeVideoWebView.observe(\.url, options: .new){_,change in
            if change.newValue == nil{
                return
            }
            // URL 抽出
            let activeUrl: URL? = change.newValue!
            let nowURL = activeUrl?.absoluteString
            // クエリを抽出
            if nowURL == nil {
                self.addOKINIIRIBtn.isHidden = true
                return
            }
            if nowURL!.hasPrefix("https://www.youtube.com/watch?") || nowURL!.hasPrefix("https://m.youtube.com/watch?"){
                self.youtubeBtnHideView.isHidden = false
            }else{
                self.youtubeBtnHideView.isHidden = true
            }
            let comp: NSURLComponents? = NSURLComponents(string: nowURL!)
            let fragments = self.generateDictionalyFromUrlComponents(components: comp!)
            if fragments["v"] == nil {
                self.addOKINIIRIBtn.isHidden = true
                return
            }
            //お気に入りに登録されているか検索する
            let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
            let context:NSManagedObjectContext = appDelegate.managedObjectContext
            let fetchRequest:NSFetchRequest<MVModel> = MVModel.fetchRequest()
            let predicate = NSPredicate(format:"%K = %@","videoID",fragments["v"]!)
            fetchRequest.predicate = predicate
            let fetchData = try! context.fetch(fetchRequest)
            if(!fetchData.isEmpty){
                self.addOKINIIRIBtn.setTitle(localText(key:"okiniiri_delete"), for: .normal)
                self.addOKINIIRIBtn.setTitleColor(self.color, for: .normal)
                self.addOKINIIRIBtn.sizeToFit()
                self.addFlg = false
            } else {
                self.addOKINIIRIBtn.setTitle(localText(key:"okiniiri_regist"), for: .normal)
                self.addOKINIIRIBtn.setTitleColor(NAVIGATION_BTN_COLOR[NOW_COLOR_THEMA][self.fromView.rawValue], for: .normal)
                self.addOKINIIRIBtn.sizeToFit()
                self.addFlg = true
            }
            self.addOKINIIRIBtn.isHidden = false
            //self.getNowYotebeInfo()
        })
        //videoView.addSubview(youtubeVideoWebView)
        
    }
    /*****************************************************************
     画面描画時の処理
     *******************************************************************/
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 動画は一旦止める
        if AVPlayerViewControllerManager.shared.controller.player != nil {
            AVPlayerViewControllerManager.shared.controller.player?.pause()
        }
        youtubeBtnHideView.isHidden = true
        selectMusicView.isHidden = true
        // navigationbarの色設定
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][fromView.rawValue]
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][fromView.rawValue]]
            self.navigationController!.navigationBar.standardAppearance = appearance
            self.navigationController!.navigationBar.scrollEdgeAppearance = self.navigationController!.navigationBar.standardAppearance
            self.navigationController!.navigationBar.tintColor = NAVIGATION_BTN_COLOR[NOW_COLOR_THEMA][fromView.rawValue]
        } else {
            self.navigationController?.navigationBar.barTintColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][fromView.rawValue]
            self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][fromView.rawValue]]
            self.navigationController!.navigationBar.tintColor = NAVIGATION_BTN_COLOR[NOW_COLOR_THEMA][fromView.rawValue]
        }
        
        color = UIColor.lightGray
        NotificationCenter.default.addObserver(self, selector: #selector(self.reachabilityChanged),name: ReachabilityChangedNotification,object: reachability)
        do{
            try reachability.startNotifier()
        }catch{
            print("could not start reachability notifier")
        }
        //お気に入りに登録されているか検索する
        let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
        let context:NSManagedObjectContext = appDelegate.managedObjectContext
        let fetchRequest:NSFetchRequest<MVModel> = MVModel.fetchRequest()
        let predicate = NSPredicate(format:"%K = %@","videoID",nowYoutubeVideoID)
        fetchRequest.predicate = predicate
        let fetchData = try! context.fetch(fetchRequest)
        if(!fetchData.isEmpty){
            addOKINIIRIBtn.setTitle(localText(key:"okiniiri_delete"), for: .normal)
            addOKINIIRIBtn.setTitleColor(color, for: .normal)
            addOKINIIRIBtn.sizeToFit()
            addFlg = false
        } else {
            addOKINIIRIBtn.setTitle(localText(key:"okiniiri_regist"), for: .normal)
            addOKINIIRIBtn.setTitleColor(NAVIGATION_BTN_COLOR[NOW_COLOR_THEMA][fromView.rawValue], for: .normal)
            addOKINIIRIBtn.sizeToFit()
            addFlg = true
        }
        self.addOKINIIRIBtn.isHidden = false
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    /*******************************************************************
     WKWebView Delegate処理
     *******************************************************************/
    // 遷移開始時
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        waitView.isHidden = true
        youtubeBtnHideView.isHidden = false
    }
    // Load完了時
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        waitView.isHidden = true
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url?.absoluteString{
            if(url.hasPrefix("https://www.youtube.com/watch?v=")){
                decisionHandler(WKNavigationActionPolicy.allow)
            }else{
                decisionHandler(WKNavigationActionPolicy.allow)
            }
        }
    }
    /*******************************************************************
     html分解処理
     *******************************************************************/
    // htmlの情報取得
    func generateDictionalyFromUrlComponents(components: NSURLComponents) -> [String : String] {
        var fragments: [String : String] = [:]
        guard let items = components.queryItems else {
            return fragments
        }
        for item in items {
            fragments[item.name] = item.value
        }
        return fragments
    }
    // Youtubeの情報を更新
    func getNowYotebeInfo(completion: @escaping (_ rs : Bool)->Void) {
        // URL 抽出
        let activeUrl: URL? = youtubeVideoWebView.url
        let nowURL = activeUrl?.absoluteString
        // クエリを抽出
        let comp: NSURLComponents? = NSURLComponents(string: nowURL!)
        let fragments = generateDictionalyFromUrlComponents(components: comp!)
        
        if fragments["v"] != nil {
            nowYoutubeVideoID = fragments["v"]!
            
            let session = URLSession.shared
            var jsonResult : NSDictionary? = NSDictionary()
            let videoInfoUrl: String = "https://www.googleapis.com/youtube/v3/videos?part=snippet,statistics,contentDetails&key=\(API_KEY)&id=\(nowYoutubeVideoID)"
            let taskVideoInfo = session.dataTask(with: URLRequest(url: URL(string: videoInfoUrl)!), completionHandler: {
                (data, response, error) in
                
                do {
                    if data == nil {
                        self.youtubeVideoTitle = self.youtubeVideoWebView.title!
                        self.youtubeVideoThumbnailUrl = "https://i.ytimg.com/vi/" + self.nowYoutubeVideoID + "/mqdefault.jpg"
                        self.youtubeVideoTime = "??:??"
                        self.addOKINIIRIBtn.isHidden = false
                        completion(true)
                        return
                    }
                    jsonResult = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? NSDictionary
                    if jsonResult == nil || jsonResult!.object(forKey: "items") == nil{
                        self.youtubeVideoTitle = self.youtubeVideoWebView.title!
                        self.youtubeVideoThumbnailUrl = "https://i.ytimg.com/vi/" + self.nowYoutubeVideoID + "/mqdefault.jpg"
                        self.youtubeVideoTime = "??:??"
                        self.addOKINIIRIBtn.isHidden = false
                        completion(true)
                        return
                    }
                    // read json response
                    self.itemsInfoArray = (jsonResult!.object(forKey: "items") as? [AnyObject])!
                    let imageUrl: NSString = "https://i.ytimg.com/vi/" + self.nowYoutubeVideoID + "/mqdefault.jpg" as NSString
                    let snippet = self.itemsInfoArray[0].object(forKey: "snippet") as! NSDictionary
                    //let snippet = self.itemsInfoArray[0]["snippet"] as AnyObject
                    // 動画の再生時間を取得
                    let contentDetails = self.itemsInfoArray[0].object(forKey: "contentDetails") as! NSDictionary
                    //let contentDetails : AnyObject = self.itemsInfoArray[0]["contentDetails"] as AnyObject
                    var duration = contentDetails["duration"] as! String
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
                    DispatchQueue.main.async {
                        self.youtubeVideoTitle = snippet["title"] as? String ?? "No Title"
                        self.youtubeVideoThumbnailUrl = imageUrl as String
                        self.youtubeVideoTime = duration
                        self.addOKINIIRIBtn.isHidden = false
                        completion(true)
                    }
                } catch {
                    completion(false)
                }
                
            })
            taskVideoInfo.resume()
            self.addOKINIIRIBtn.isHidden = false
        }
    }
    
    /*******************************************************************
     ボタンタップ処理
     *******************************************************************/
    // お気に入り動画に追加/削除
    @IBAction func addOKINIIRIBtnTapped(_ sender: Any) {
        // URL 抽出
        let activeUrl: URL? = youtubeVideoWebView.url
        let nowURL = activeUrl?.absoluteString
        // クエリを抽出
        if nowURL == nil {
            return
        }
        let comp: NSURLComponents? = NSURLComponents(string: nowURL!)
        let fragments = self.generateDictionalyFromUrlComponents(components: comp!)
        if fragments["v"] != nil {
            self.nowYoutubeVideoID = fragments["v"]!
        }
        if self.addFlg {
            getNowYotebeInfo(completion: {(rs: Bool)  -> Void in
                if rs {
                    // 登録する
                    DispatchQueue.main.async {
                        let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
                        let MVContext:NSManagedObjectContext = appDelegate.managedObjectContext
                        let MVEntity = NSEntityDescription.entity(forEntityName: "MVModel", in: MVContext)
                        let MVlistModel = NSManagedObject(entity:MVEntity!,insertInto:MVContext) as! MVModel
                        // 登録されているMVModel数を取得
                        let fetchRequest:NSFetchRequest<MVModel> = MVModel.fetchRequest()
                        let fetchData = try! MVContext.fetch(fetchRequest)
                        if(!fetchData.isEmpty){
                            MVlistModel.indicatoryNum = Int16(fetchData.count)
                        }else{
                            MVlistModel.indicatoryNum = 0
                        }
                        // 登録されている「お気に入り動画」数も更新
                        let appDelegateC:AppDelegate = UIApplication.shared.delegate as! AppDelegate
                        let contextC:NSManagedObjectContext = appDelegateC.managedObjectContext
                        let fetchRequestC:NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
                        let fetchDataC = try! contextC.fetch(fetchRequestC)
                        if(!fetchDataC.isEmpty){
                            for i in 0..<fetchDataC.count{
                                if fetchDataC[i].musicLibraryName == MV_LIST_NAME{
                                    if(!fetchData.isEmpty){
                                        fetchDataC[i].trackNum = Int16(fetchData.count)
                                    }else{
                                        fetchDataC[i].trackNum = 0
                                    }
                                }
                            }
                        }
                        MVlistModel.videoID = self.nowYoutubeVideoID
                        MVlistModel.musicLibraryName = MV_LIST_NAME
                        MVlistModel.thumbnailUrl = self.youtubeVideoThumbnailUrl
                        MVlistModel.videoTitle = self.youtubeVideoTitle
                        MVlistModel.videoTime = self.youtubeVideoTime
                        do{
                            try MVContext.save()
                            try contextC.save()
                        }catch{
                            print(error)
                            return
                        }
                        self.addOKINIIRIBtn.setTitle(localText(key:"okiniiri_delete"), for: .normal)
                        self.addOKINIIRIBtn.setTitleColor(self.color, for: .normal)
                        self.addOKINIIRIBtn.sizeToFit()
                        self.addFlg = false
                        showToastMsg(messege:OKINIIRI_ADD_DIALOG_MASSAGE,time:2.0, tab: self.fromView.rawValue)
                        // Firebaseに登録
                        setOkiniiriData(videoId:self.nowYoutubeVideoID,categoryID:SETTING_NOW_CATEGORYID,
                                        title:self.youtubeVideoTitle,imageUrl:self.youtubeVideoThumbnailUrl,time:self.youtubeVideoTime)
                    }
                }else{
                    
                }
            })
        } else {
            
            //削除する
            let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
            let MVContext:NSManagedObjectContext = appDelegate.managedObjectContext
            let fetchRequest:NSFetchRequest<MVModel> = MVModel.fetchRequest()
            let predicate = NSPredicate(format:"%K = %@","videoID",self.nowYoutubeVideoID)
            fetchRequest.predicate = predicate
            let fetchData = try! MVContext.fetch(fetchRequest)
            if(!fetchData.isEmpty){
                for i in 0..<fetchData.count{
                    let deleteObject = fetchData[i] as MVModel
                    MVContext.delete(deleteObject)
                }
                
            }
            do{
                try MVContext.save()
                
            }catch{
                print(error)
                return
            }
            // 登録されている「お気に入り動画」数も更新
            let appDelegateB:AppDelegate = UIApplication.shared.delegate as! AppDelegate
            let contextB:NSManagedObjectContext = appDelegateB.managedObjectContext
            let fetchRequestB:NSFetchRequest<MVModel> = MVModel.fetchRequest()
            let fetchDataB = try! contextB.fetch(fetchRequestB)
            
            let appDelegateC:AppDelegate = UIApplication.shared.delegate as! AppDelegate
            let contextC:NSManagedObjectContext = appDelegateC.managedObjectContext
            let fetchRequestC:NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
            let fetchDataC = try! contextC.fetch(fetchRequestC)
            if(!fetchDataC.isEmpty){
                for i in 0..<fetchDataC.count{
                    if fetchDataC[i].musicLibraryName == MV_LIST_NAME{
                        if(!fetchDataB.isEmpty){
                            fetchDataC[i].trackNum = Int16(fetchDataB.count)
                        }else{
                            fetchDataC[i].trackNum = 0
                        }
                    }
                }
            }
            do{
                try contextC.save()
                
            }catch{
                print(error)
                return
            }
            self.addOKINIIRIBtn.setTitle(localText(key:"okiniiri_regist"), for: .normal)
            self.addOKINIIRIBtn.setTitleColor(NAVIGATION_BTN_COLOR[NOW_COLOR_THEMA][self.fromView.rawValue], for: .normal)
            self.addOKINIIRIBtn.sizeToFit()
            self.addFlg = true
            showToastMsg(messege:OKINIIRI_DELETE_DIALOG_MASSAGE,time:2.0, tab: fromView.rawValue)
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
    
}
