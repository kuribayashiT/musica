//
//  PlayMVViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2017/07/30.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import CoreData
import AVFoundation
import GoogleMobileAds

class PlayMVViewController: UIViewController ,UICollectionViewDelegateFlowLayout, FullScreenContentDelegate {

    /*
     ボタン関連
     */
    var editDoneBtn = UIBarButtonItem()
    
    /*
     お気に入りCollectionView関連
     */
    @IBOutlet weak var bannerView: BannerView!
    var interstitial: InterstitialAd?
    @IBOutlet weak var OKINIIRICollectionView: UICollectionView!
    @IBOutlet weak var OKINIIRIEmptyView: UIView!
    var cellSize = CGSize()
    let cellMargin : CGFloat = 0.5
    let columnNum : Int = 2
    var selectPlayMVNum = 0
    var youtubeVideoIdList : [String] = []
    var youtubeVideoTimeList : [String] = []
    var youtubeVideoTitleList : [String] = []
    var youtubeVideoThumbnailUrl : [String] = []
    var youtubeVideoIndicatoryNum : [Int16] = []
    var youtubeVideoMusicLibraryName : [String] = []
    var youtubePlaylistVideoIDs = ""
    var selectedIndexPath : IndexPath = IndexPath()
    
    @IBOutlet weak var okiniiriZeroBtn: UIButton!
    var moveStartFlg = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /*
         端末によるサイズの計算とviewの設定
         */
        self.title = localText(key:"home_okiniiri_title")
        
        // 長押し時の挙動を登録
        let longPressGesture = UILongPressGestureRecognizer(target: self,
                                                            action: #selector(self.handleLongGesture))
        longPressGesture.allowableMovement = 15
        longPressGesture.minimumPressDuration = 0.3
        OKINIIRICollectionView.addGestureRecognizer(longPressGesture)
        editDoneBtn = makeEditBtn()
        navigationItem.rightBarButtonItems = [editDoneBtn]
        okiniiriZeroBtn.setTitle(localText(key:"home_tutorial_mv_message"),for: .normal)
    }

    
    /*******************************************************************
     画面描画時の処理
     *******************************************************************/
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // navigationbarの色設定
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
        
        selectMusicView.isHidden = true
        // 広告の準備
        loadInterstitial()
        
        // バックグラウンドでも再生を続けるための設定
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [])
            try audioSession.setActive(true)
        } catch let error as NSError {
            print(error)
        }
        // お気に入り情報を初期化
        self.youtubeVideoIdList = []
        self.youtubeVideoTitleList = []
        self.youtubeVideoThumbnailUrl = []
        self.youtubeVideoIndicatoryNum = []
        self.youtubeVideoMusicLibraryName = []
        self.youtubeVideoTimeList = []
        //MusicLibraryのデータを読み込む TODO ビルドできるが、エラーが消えない？？
        let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
        let context:NSManagedObjectContext = appDelegate.managedObjectContext
        let fetchRequest:NSFetchRequest<MVModel> = MVModel.fetchRequest()
        let predicate = NSPredicate(format:"%K = %@","musicLibraryName",MV_LIST_NAME)
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "indicatoryNum", ascending: true)]
        //let fetchRequest:NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
        let fetchData = try! context.fetch(fetchRequest)
        if(!fetchData.isEmpty){
            print(fetchData)
            for i in 0..<fetchData.count{
                self.youtubeVideoIdList.append(fetchData[i].videoID!)
                self.youtubeVideoTitleList.append(fetchData[i].videoTitle!)
                self.youtubeVideoThumbnailUrl.append(fetchData[i].thumbnailUrl!)
                self.youtubeVideoIndicatoryNum.append(fetchData[i].indicatoryNum)
                self.youtubeVideoMusicLibraryName.append(fetchData[i].musicLibraryName!)
                print(fetchData[i].musicLibraryName!)
                print(fetchData[i].videoTime!)
                self.youtubeVideoTimeList.append(fetchData[i].videoTime!)
//                if youtubePlaylistVideoIDs == "" {
//                    youtubePlaylistVideoIDs = fetchData[i].videoID!
//                }else{
//                    youtubePlaylistVideoIDs = youtubePlaylistVideoIDs + "," + fetchData[i].videoID!
//                }
            }
        }
        if youtubeVideoIdList.count == 0 {
            OKINIIRIEmptyView.isHidden = false
            bannerView.isHidden = true
            bannerView.adSize = currentOrientationAnchoredAdaptiveBanner(width: 0)
        }else{
            OKINIIRIEmptyView.isHidden = true
            if ADApearFlg(){
                bannerView.isHidden = false
                bannerView.adUnitID = ADMOB_BANNER_ADUNIT_ID
                bannerView.rootViewController = self
                custumLoadBannerAd(bannerView: self.bannerView,setBannerView:self.view)
            }else{
                bannerView.isHidden = true
                bannerView.adSize = currentOrientationAnchoredAdaptiveBanner(width: 10)
            }
        }
        OKINIIRICollectionView.reloadData()
    }
    func makeEditBtn() -> UIBarButtonItem{
        let button = UIButton(type: UIButton.ButtonType.system)
        button.frame.size = CGSize(width: 80, height: 30)
        button.setTitleColor(AppColor.textSecondary, for: UIControl.State.normal)
        if NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLACK.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_BLUE.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_RED.rawValue || NOW_COLOR_THEMA == NAVIGATION_COLOR_SETTINGS.WHITE_DARK_BLUE.rawValue {
            button.layer.borderWidth = 1.0
            button.layer.borderColor = AppColor.textSecondary.cgColor
        }else{
            button.layer.borderWidth = 0
            button.layer.borderColor = UIColor.clear.cgColor
        }
        button.layer.cornerRadius = 5
        button.backgroundColor = AppColor.surface
        button.addTarget(self, action: #selector(self.editDoneBtnTapped), for: UIControl.Event.touchUpInside)
        button.titleLabel?.font =  AppFont.footnote
        button.setTitle(localText(key:"btn_edit"), for: UIControl.State.normal)
        let barButton = UIBarButtonItem(customView: button)
        return barButton
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // playlistを作成
    func makePlaylist(startListNum:Int){
        var regIndex = 0
        youtubePlaylistVideoIDs = ""
        for i in 0..<youtubeVideoIdList.count{
            if startListNum + i >= youtubeVideoIdList.count-1{
                regIndex = i
            }else{
                regIndex = startListNum + i
            }
            if regIndex == startListNum{
                continue
            }
            if youtubePlaylistVideoIDs == "" {
                youtubePlaylistVideoIDs = youtubeVideoIdList[regIndex]
            }else{
                youtubePlaylistVideoIDs = youtubePlaylistVideoIDs + "," + youtubeVideoIdList[regIndex]
            }
            
        }
        
    }
    // アイコンフヨフヨアニメーション
    func vibrated(vibrated:Bool, view: UIView) {
        if vibrated {
            var animation: CABasicAnimation
            animation = CABasicAnimation(keyPath: "transform.rotation")
            let fValue = Float.random(in: 0.1 ... 0.5)
            animation.duration = 0.15
            animation.beginTime = CFTimeInterval(fValue)
            animation.fromValue = degreesToRadians(degrees: 2.0)
            animation.toValue = degreesToRadians(degrees: -2.0)
            animation.repeatCount = Float.infinity
            animation.autoreverses = true
            view.layer.add(animation, forKey: "VibrateAnimationKey")
        }else {
            view.layer.removeAnimation(forKey: "VibrateAnimationKey")
        }
    }
    func degreesToRadians(degrees: Float) -> Float {
        return degrees * Float(Double.pi) / 180.0
    }
    /*******************************************************************
     ボタンタップ時処理
     *******************************************************************/
    // 編集完了ボタンタップ時
    @objc func editDoneBtnTapped(_ sender: Any) {
        // 動画は一旦止める
        if AVPlayerViewControllerManager.shared.controller.player != nil {
            AVPlayerViewControllerManager.shared.controller.player?.pause()
        }
        if editDoneBtn.title == localText(key:"btn_edit") {
            editDoneBtn.title = localText(key:"home_edit_comp")
            let bn = editDoneBtn.customView! as! UIButton
            bn.setTitle(editDoneBtn.title, for: .normal)
            MV_SORT_ORDER_EDIT_FLG = true
            
            for i in 0..<youtubeVideoIdList.count {
                let indexPath = IndexPath(row: i, section: 0)
                (OKINIIRICollectionView.cellForItem(at: indexPath) as? OKINIIRICollectionViewCell)?.deleteBtn.isHidden = false
            }
            
        }else{
            editDoneBtn.title = localText(key:"btn_edit")
            let bn = editDoneBtn.customView! as! UIButton
            bn.setTitle(editDoneBtn.title, for: .normal)
            for i in 0..<youtubeVideoIdList.count {
                let indexPath = IndexPath(row: i, section: 0)
                (OKINIIRICollectionView.cellForItem(at: indexPath) as? OKINIIRICollectionViewCell)?.deleteBtn.isHidden = true
            }
            MV_SORT_ORDER_EDIT_FLG = false
            
            let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
            let context:NSManagedObjectContext = appDelegate.managedObjectContext
            let fetchRequest:NSFetchRequest<MVModel> = MVModel.fetchRequest()
            let fetchData = try! context.fetch(fetchRequest)
            // 並び替え後のデータを保存
            if(!fetchData.isEmpty){
                for i in 0..<youtubeVideoIdList.count{
                    for j in 0..<fetchData.count{
                        if fetchData[j].videoID == youtubeVideoIdList[i]{
                            fetchData[j].indicatoryNum = Int16(i)
                        }
                    }
                }
                do{
                    try context.save()
                }catch{
                    print(error)
                }
            }
        }
        
        if youtubeVideoIdList.count == 0 {
            OKINIIRIEmptyView.isHidden = false
        }else{
            OKINIIRIEmptyView.isHidden = true
        }
        OKINIIRICollectionView.reloadData()
    }
    
    //削除ボタンタップ時の処理
    @IBAction func deleteBtnTapped(_ sender: Any) {
        let index = (sender as AnyObject).tag
        //MusicLibraryのデータを削除する
        let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
        let mvIdContext:NSManagedObjectContext = appDelegate.managedObjectContext
        let mvIdFetchRequest:NSFetchRequest<MVModel> = MVModel.fetchRequest()
        let mvIdPredicate = NSPredicate(format:"%K = %@","videoID",youtubeVideoIdList[index!])
        mvIdFetchRequest.predicate = mvIdPredicate
        let mvIdFetchData = try! mvIdContext.fetch(mvIdFetchRequest)
    
        if(!mvIdFetchData.isEmpty){
            for i in 0..<mvIdFetchData.count{
                let deleteObject = mvIdFetchData[i] as MVModel
                mvIdContext.delete(deleteObject)
                print(deleteObject)
            }
            do{
                try mvIdContext.save()
                //元の位置のデータを配列から削除する。
                youtubeVideoIdList.remove(at: index!)
                youtubeVideoTitleList.remove(at: index!)
                youtubeVideoThumbnailUrl.remove(at: index!)
                youtubeVideoTimeList.remove(at: index!)
            }catch{
                print(error)
            }
        }
        // 登録されている「お気に入り動画」数も更新
        let appDelegateC:AppDelegate = UIApplication.shared.delegate as! AppDelegate
        let contextC:NSManagedObjectContext = appDelegateC.managedObjectContext
        let fetchRequestC:NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
        let fetchDataC = try! contextC.fetch(fetchRequestC)
        if(!fetchDataC.isEmpty){
            for i in 0..<fetchDataC.count{
                if fetchDataC[i].musicLibraryName == MV_LIST_NAME{
        
                fetchDataC[i].trackNum = Int16(youtubeVideoIdList.count)
            }
        }
        do{
            try mvIdContext.save()
            try contextC.save()
                        
        }catch{
            print(error)
            return
        }
            //テーブルの再読み込み
            if youtubeVideoIdList.count == 0 {
                OKINIIRIEmptyView.isHidden = false
            }else{
                OKINIIRIEmptyView.isHidden = true
            }
            OKINIIRICollectionView.reloadData()
        }
    }
    /*******************************************************************
     お気に入りcollectionViewの設定
     *******************************************************************/
    //セルサイズの指定（UICollectionViewDelegateFlowLayoutで必須）　横幅いっぱいにセルが広がるようにしたい
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let widths:CGFloat = ((collectionView.frame.size.width - cellMargin * 2 * CGFloat(columnNum))/CGFloat(columnNum))
        let heights:CGFloat = widths
        cellSize = CGSize(width:widths,height:heights)
        return cellSize
    }
    
    //セルの水平方向のマージンを設定
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return cellMargin
    }
    //セルの垂直方向のマージンを設定
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return cellMargin * 2
    }
    
    //セルをクリックしたら呼ばれる
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        if editDoneBtn.title == localText(key:"home_edit_comp") {
            return
        }
        if UserDefaults.standard.object(forKey: "mvCount") == nil{
            UserDefaults.standard.set(1, forKey: "mvCount")
        }else{
            MV_PLAY_NUM = UserDefaults.standard.integer(forKey: "mvCount") + 1
            UserDefaults.standard.set(MV_PLAY_NUM, forKey: "mvCount")
        }
        // 最初に広告が出るのを避ける
        if AD_DISPLAY_YOUTUBE_CONTENTS_NUM != 0 {
            if MV_PLAY_NUM % AD_DISPLAY_YOUTUBE_CONTENTS_NUM == 0{
                if AD_DISPLAY_YOUTUBE_CONTENTS != false{
                    if interstitial != nil {
                        if interstitial != nil {
                            interstitial?.present(from: self)
                        }
                    }
                }
            }
        }
        selectPlayMVNum = indexPath.row
        // playList作成
        //makePlaylist(startListNum: selectPlayMVNum)
        //_ = NSURL(string: "https://www.youtube.com/watch?v=" + self.youtubeVideoIdList[selectPlayMVNum])
        // toYoutubePlaylistPlayer
        performSegue(withIdentifier: "toYoutubePlaylistPlayer",sender: "")
    }
    @IBAction func okiniiriZeroBtnTApped(_ sender: Any) {
        showToastMsg(messege:localText(key:"home_tutorial_tapped_message"),time:2.0, tab: COLOR_THEMA.SEARCH.rawValue)
    }
    /*******************************************************************
     画面遷移時処理
     *******************************************************************/
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        MV_SORT_ORDER_EDIT_FLG = false
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //MV再生画面へ
        // toYoutubePlaylistPlayer
        if segue.identifier == "toYoutubePlaylistPlayer" {
            let secondVc = segue.destination as! YoutubePlayViewController
            // 値を渡す
            //secondVc.youtubeVideoID = self.youtubeVideoIdList[selectPlayMVNum]
            secondVc.youtubeVideoIdList = self.youtubeVideoIdList
            secondVc.selectedVideoNum = selectPlayMVNum
        }
    }
    /*******************************************************************
     広告（Admob）の処理
     *******************************************************************/
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd){
        loadInterstitial()
    }
    func loadInterstitial() {
        InterstitialAd.load(with: ADMOB_INTERSTITIAL_MV, request: Request()) { [weak self] ad, error in
            if let error = error { print("Interstitial failed to load: \(error)"); return }
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
        }
    }
    func adWillLeaveApplication(_ ad: FullScreenPresentingAd) {
        self.dismiss(animated: true, completion: nil)
    }
}

/*******************************************************************
 お気に入りcollectionViewのextension(更新処理を記載）
 *******************************************************************/
extension PlayMVViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return youtubeVideoIdList.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TestCell", for: indexPath as IndexPath) as! OKINIIRICollectionViewCell
        // 動画の再生時間を取得
        if youtubeVideoTimeList[(indexPath as NSIndexPath).row] == "" {
            cell.youtubeVideoTimeLabel.text = "--:--"
        }else{
            cell.youtubeVideoTimeLabel.text = youtubeVideoTimeList[(indexPath as NSIndexPath).row]
        }
        
        // 動画のタイトルを取得
        cell.youtubeVideoTitle.text = youtubeVideoTitleList[(indexPath as NSIndexPath).row]
        if columnNum == 2 {
            cell.youtubeVideoTitle.font = UIFont(name: "Thonburi", size: 10)
        }else if columnNum == 3 {
            cell.youtubeVideoTitle.font = UIFont(name: "Thonburi", size: 7)
        }
        // 画像の表示調整
        cell.youtubeVideoThumbnail.backgroundColor = AppColor.surface
        cell.youtubeVideoThumbnail.contentMode = .scaleAspectFit
        cell.youtubeVideoThumbnail.layer.borderColor = AppColor.border.cgColor
        //imgUrlStringをNSURL型に変換
        let imgUrl: NSURL = NSURL(string: youtubeVideoThumbnailUrl[(indexPath as NSIndexPath).row])!
        //画像データに変換
        cell.youtubeVideoThumbnail.sd_setImage(with: imgUrl as URL)
        
        //削除ボタンの設定
        if editDoneBtn.title == localText(key:"home_edit_comp") {
            if cell.deleteBtn.isHidden {
                cell.deleteBtn.isHidden = false
                iconPopUpAnimesion(view : cell.deleteBtn)
            }
            cell.deleteBtn.tag = (indexPath as NSIndexPath).row
        }else{
            if !cell.deleteBtn.isHidden {
                cell.deleteBtn.isHidden = true
                iconPopDownAnimesion(view : cell.deleteBtn)
            }
            cell.deleteBtn.tag = (indexPath as NSIndexPath).row
        }
        if MV_SORT_ORDER_EDIT_FLG == false {
            cell.youtubeView.layer.cornerRadius = 0
            cell.youtubeView.clipsToBounds = true
            cell.transform = CGAffineTransform(scaleX: 1, y: 1)
            editDoneBtn.title = localText(key:"btn_edit")
            let bn = editDoneBtn.customView! as! UIButton
            bn.setTitle(editDoneBtn.title, for: .normal)
            editDoneBtn.setTitleTextAttributes([NSAttributedString.Key.font: AppFont.title2], for: UIControl.State.normal)
            cell.deleteBtn.tag = (indexPath as NSIndexPath).row
            cell.deleteBtn.isHidden = true
        }else{
            vibrated(vibrated: true, view: cell)
            cell.youtubeView.layer.cornerRadius = 10
            cell.transform = CGAffineTransform(scaleX: 9/10, y: 9/10)
            cell.youtubeView.clipsToBounds = true
            cell.deleteBtn.tag = (indexPath as NSIndexPath).row
            cell.deleteBtn.isHidden = false
            editDoneBtn.tintColor = NAVIGATION_BTN_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
            editDoneBtn.title = localText(key:"home_edit_comp")
            let bn = editDoneBtn.customView! as! UIButton
            bn.setTitle(editDoneBtn.title, for: .normal)
            editDoneBtn.setTitleTextAttributes([NSAttributedString.Key.font: AppFont.title2], for: UIControl.State.normal)
            MV_SORT_ORDER_EDIT_FLG = true
        }
        return cell
    }
    
    // 並び順変更
    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {

        //移動されたデータを取得する。
        let temp01 = youtubeVideoIdList.remove(at: sourceIndexPath.item)
        let temp02 = youtubeVideoTitleList.remove(at: sourceIndexPath.item)
        let temp03 = youtubeVideoThumbnailUrl.remove(at: sourceIndexPath.item)
        let temp04 = youtubeVideoTimeList.remove(at: sourceIndexPath.item)
        //移動先の位置にデータを配列に挿入する。
        youtubeVideoIdList.insert(temp01, at: destinationIndexPath.item)
        youtubeVideoTitleList.insert(temp02, at: destinationIndexPath.item)
        youtubeVideoThumbnailUrl.insert(temp03, at: destinationIndexPath.item)
        youtubeVideoTimeList.insert(temp04, at: destinationIndexPath.item)
        
        let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
        let context:NSManagedObjectContext = appDelegate.managedObjectContext
        let fetchRequest:NSFetchRequest<MVModel> = MVModel.fetchRequest()
        let fetchData = try! context.fetch(fetchRequest)
        // 並び替え後のデータを保存
        if(!fetchData.isEmpty){
            for i in 0..<youtubeVideoIdList.count{
                for j in 0..<fetchData.count{
                    if fetchData[j].videoID == youtubeVideoIdList[i]{
                        fetchData[j].indicatoryNum = Int16(i)
                    }
                }
            }
            do{
                try context.save()
            }catch{
                print(error)
            }
        }
        OKINIIRICollectionView.reloadData()
    }
    
    
    // 編集モード
    @objc func handleLongGesture(gesture: UILongPressGestureRecognizer) {
        
        guard OKINIIRICollectionView.indexPathForItem(at: gesture.location(in: OKINIIRICollectionView)) != nil else{
            // 存在しないパスはスルー
            return
        }
        
        if MV_SORT_ORDER_EDIT_FLG == false {
            MV_SORT_ORDER_EDIT_FLG = true
            OKINIIRICollectionView.reloadData()
            return
        }
        
        // iOS verによって、CollectionViewの挙動が違うため処理わけ
        if #available(iOS 11.0, *) {
            // iOS11以降の場合
            switch(gesture.state) {
            case UIGestureRecognizer.State.began:
                if moveStartFlg == true{
                    break
                }
                selectedIndexPath = OKINIIRICollectionView.indexPathForItem(at: gesture.location(in: OKINIIRICollectionView))!
                OKINIIRICollectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
                //アニメーション処理
                UIView.animate(withDuration: 0.1 , animations: {
                    //拡大縮小の処理
                    self.OKINIIRICollectionView.cellForItem(at: self.selectedIndexPath)?.frame = CGRect(x:gesture.location(in: gesture.view!).x-self.cellSize.width*5/9, y:gesture.location(in: gesture.view!).y - self.cellSize.height*5/9, width:self.cellSize.width*10/9, height:self.cellSize.height*10/9)
                })
                moveStartFlg = true
                
            case UIGestureRecognizer.State.changed:
                if moveStartFlg == false{
                    selectedIndexPath = OKINIIRICollectionView.indexPathForItem(at: gesture.location(in: OKINIIRICollectionView))!
                    OKINIIRICollectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
                    //拡大縮小の処理
                    self.OKINIIRICollectionView.cellForItem(at: self.selectedIndexPath)?.frame = CGRect(x:gesture.location(in: gesture.view!).x-self.cellSize.width*10/9, y:gesture.location(in: gesture.view!).y - self.cellSize.height*10/9, width:self.cellSize.width*10/9, height:self.cellSize.height*10/9)
                    moveStartFlg = true
                }
                for cellIndex in OKINIIRICollectionView.indexPathsForVisibleItems {
                    if cellIndex != self.selectedIndexPath{
                        self.OKINIIRICollectionView.cellForItem(at: cellIndex)?.transform = CGAffineTransform(scaleX: 9/10, y: 9/10)
                    }
                }
                OKINIIRICollectionView.updateInteractiveMovementTargetPosition(gesture.location(in: gesture.view!))
                
            case UIGestureRecognizer.State.ended:
                OKINIIRICollectionView.endInteractiveMovement()
                for cellIndex in OKINIIRICollectionView.indexPathsForVisibleItems {
                    self.OKINIIRICollectionView.cellForItem(at: cellIndex)?.transform = CGAffineTransform(scaleX: 9/10, y: 9/10)
                }
                moveStartFlg = false
                OKINIIRICollectionView.reloadData()
                
            case UIGestureRecognizer.State.cancelled:
                selectedIndexPath = OKINIIRICollectionView.indexPathForItem(at: gesture.location(in: OKINIIRICollectionView))!
                //self.OKINIIRICollectionView.cellForItem(at: selectedIndexPath)?.transform = CGAffineTransform(scaleX: 9/10, y: 9/10)

                for cellIndex in OKINIIRICollectionView.indexPathsForVisibleItems {
                    self.OKINIIRICollectionView.cellForItem(at: cellIndex)?.transform = CGAffineTransform(scaleX: 9/10, y: 9/10)
                }
                //OKINIIRICollectionView.updateInteractiveMovementTargetPosition(gesture.location(in: gesture.view!))
                moveStartFlg = false
            default:
                OKINIIRICollectionView.cancelInteractiveMovement()
                moveStartFlg = false
            }
        } else {
            // iOS10以前の場合
            switch(gesture.state) {
                
            case UIGestureRecognizer.State.began:
                if moveStartFlg == true{
                    break
                }
                guard let selectedIndexPath = OKINIIRICollectionView.indexPathForItem(at: gesture.location(in: OKINIIRICollectionView)) else{
                    break
                }
                OKINIIRICollectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
                //アニメーション処理
                UIView.animate(withDuration: 0.3 , animations: {
                    
                    //拡大縮小の処理
                    self.OKINIIRICollectionView.cellForItem(at: self.selectedIndexPath)?.frame = CGRect(x:gesture.location(in: gesture.view!).x-self.cellSize.width*5/9, y:gesture.location(in: gesture.view!).y - self.cellSize.height*5/9, width:self.cellSize.width*10/9, height:self.cellSize.height*10/9)
                    
                })
                moveStartFlg = true
                
            case UIGestureRecognizer.State.changed:
                if moveStartFlg == false{
                    guard let selectedIndexPath = OKINIIRICollectionView.indexPathForItem(at: gesture.location(in: OKINIIRICollectionView)) else{
                        break
                    }
                    OKINIIRICollectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
                    //アニメーション処理
                    UIView.animate(withDuration: 0.3, animations: {
                        
                        //拡大縮小の処理
                        self.OKINIIRICollectionView.cellForItem(at: self.selectedIndexPath)?.frame = CGRect(x:gesture.location(in: gesture.view!).x-self.cellSize.width*5/9, y:gesture.location(in: gesture.view!).y - self.cellSize.height*5/9, width:self.cellSize.width*10/9, height:self.cellSize.height*10/9)
                        
                    })
                    moveStartFlg = true
                }
                guard let selectedIndexPath = OKINIIRICollectionView.indexPathForItem(at: gesture.location(in: OKINIIRICollectionView)) else{
                    break
                }
                OKINIIRICollectionView.updateInteractiveMovementTargetPosition(gesture.location(in: gesture.view!))
                self.OKINIIRICollectionView.cellForItem(at: selectedIndexPath)?.frame = CGRect(x:gesture.location(in: gesture.view!).x-self.cellSize.width*5/9, y:gesture.location(in: gesture.view!).y - self.cellSize.height*5/9, width:self.cellSize.width*10/9, height:self.cellSize.height*10/9)
                
            case UIGestureRecognizer.State.ended:
                OKINIIRICollectionView.endInteractiveMovement()
                moveStartFlg = false
                OKINIIRICollectionView.reloadData()
                
            case UIGestureRecognizer.State.cancelled:
                guard let selectedIndexPath = OKINIIRICollectionView.indexPathForItem(at: gesture.location(in: OKINIIRICollectionView)) else{
                    break
                }
                OKINIIRICollectionView.updateInteractiveMovementTargetPosition(gesture.location(in: gesture.view!))
                self.OKINIIRICollectionView.cellForItem(at: selectedIndexPath)?.frame = CGRect(x:gesture.location(in: gesture.view!).x-self.cellSize.width/2, y:gesture.location(in: gesture.view!).y - self.cellSize.height/2, width:self.cellSize.width, height:self.cellSize.height)
                
                moveStartFlg = false
            default:
                OKINIIRICollectionView.cancelInteractiveMovement()
                moveStartFlg = false
            }
        }
    }
}

