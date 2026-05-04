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
    let cellMargin : CGFloat = 12       // セル間スペース
    let sectionInset: CGFloat = 16      // 画面端パディング
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
        let helpBtn = makeHelpBtn()
        let addBtn  = makeAddBtn()
        navigationItem.rightBarButtonItems = [editDoneBtn, addBtn, helpBtn]

        // コレクションビュー背景（セルと区別できる色）
        OKINIIRICollectionView.backgroundColor = AppColor.background
        OKINIIRICollectionView.contentInsetAdjustmentBehavior = .automatic

        // 空状態ボタン（Apple Music 風 CTA）
        okiniiriZeroBtn.setTitle(localText(key:"home_tutorial_mv_message"), for: .normal)
        okiniiriZeroBtn.setTitleColor(AppColor.accent, for: .normal)
        okiniiriZeroBtn.backgroundColor = AppColor.accentMuted
        okiniiriZeroBtn.layer.cornerRadius = 14
        okiniiriZeroBtn.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
    }

    
    /*******************************************************************
     画面描画時の処理
     *******************************************************************/
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // navigationbarの色設定
        self.navigationController?.navigationBar.isTranslucent = true
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        navAppearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: AppColor.textPrimary]
        self.navigationController?.navigationBar.standardAppearance = navAppearance
        self.navigationController?.navigationBar.scrollEdgeAppearance = navAppearance
        self.navigationController?.navigationBar.compactAppearance = navAppearance
        self.navigationController?.navigationBar.tintColor = AppColor.accent
        
        selectMusicView.isHidden = true
        // 広告の準備
        loadInterstitial()
        
        // バックグラウンドでも再生を続けるための設定
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [])
            try audioSession.setActive(true)
        } catch let error as NSError {
            dlog(error)
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
            dlog(fetchData)
            for i in 0..<fetchData.count{
                self.youtubeVideoIdList.append(fetchData[i].videoID!)
                self.youtubeVideoTitleList.append(fetchData[i].videoTitle!)
                self.youtubeVideoThumbnailUrl.append(fetchData[i].thumbnailUrl!)
                self.youtubeVideoIndicatoryNum.append(fetchData[i].indicatoryNum)
                self.youtubeVideoMusicLibraryName.append(fetchData[i].musicLibraryName!)
                dlog(fetchData[i].musicLibraryName!)
                dlog(fetchData[i].videoTime!)
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
    func makeAddBtn() -> UIBarButtonItem {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.tintColor = AppColor.accent
        button.addTarget(self, action: #selector(addBtnTapped), for: .touchUpInside)
        button.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        return UIBarButtonItem(customView: button)
    }

    @objc func addBtnTapped() {
        let alert = UIAlertController(
            title: localText(key: "mv_add_title"),
            message: localText(key: "mv_add_message"),
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "https://www.youtube.com/watch?v=..."
            tf.keyboardType = .URL
            tf.autocorrectionType = .no
            tf.autocapitalizationType = .none
            // クリップボードにURLがあれば自動でセット
            if let clip = UIPasteboard.general.string,
               Self.extractVideoID(from: clip) != nil {
                tf.text = clip
            }
        }
        alert.addAction(UIAlertAction(title: localText(key: "mv_add_btn"), style: .default) { [weak self, weak alert] _ in
            guard let self = self,
                  let urlString = alert?.textFields?.first?.text,
                  let videoID = Self.extractVideoID(from: urlString) else {
                showToastMsg(messege: localText(key: "mv_invalid_url"), time: 2.0, tab: 1)
                return
            }
            self.registerVideoID(videoID)
        })
        alert.addAction(UIAlertAction(title: localText(key: "btn_cancel"), style: .cancel))
        present(alert, animated: true)
    }

    /// YouTube URL から videoID を抽出（watch?v= / youtu.be/ 両対応）
    static func extractVideoID(from urlString: String) -> String? {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host else { return nil }
        if host.contains("youtu.be") {
            let id = url.pathComponents.dropFirst().first ?? ""
            return id.isEmpty ? nil : String(id)
        }
        if host.contains("youtube.com") {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let v = components?.queryItems?.first(where: { $0.name == "v" })?.value,
               !v.isEmpty { return v }
            // /shorts/XXXX 形式
            if let idx = url.pathComponents.firstIndex(of: "shorts"),
               url.pathComponents.indices.contains(idx + 1) {
                return url.pathComponents[idx + 1]
            }
        }
        return nil
    }

    /// videoID を CoreData に登録し、oEmbed でタイトル取得
    private func registerVideoID(_ videoID: String) {
        // 重複チェック
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let ctx = appDelegate.managedObjectContext
        let dupReq: NSFetchRequest<MVModel> = MVModel.fetchRequest()
        dupReq.predicate = NSPredicate(format: "videoID = %@ AND musicLibraryName = %@", videoID, MV_LIST_NAME)
        if (try? ctx.fetch(dupReq))?.isEmpty == false {
            showToastMsg(messege: localText(key: "mv_already_added"), time: 2.0, tab: 1)
            return
        }

        // タイトルをoEmbedで取得（失敗時はvideoIDで仮登録）
        let oembedURL = URL(string: "https://www.youtube.com/oembed?url=https://www.youtube.com/watch%3Fv%3D\(videoID)&format=json")!
        URLSession.shared.dataTask(with: oembedURL) { [weak self] data, _, _ in
            var title = videoID
            if let data = data,
               let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               let t = json["title"] as? String { title = t }
            DispatchQueue.main.async {
                self?.saveVideo(videoID: videoID, title: title)
            }
        }.resume()
    }

    private func saveVideo(videoID: String, title: String) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let ctx = appDelegate.managedObjectContext

        // indicatoryNum = 既存件数
        let allReq: NSFetchRequest<MVModel> = MVModel.fetchRequest()
        allReq.predicate = NSPredicate(format: "musicLibraryName = %@", MV_LIST_NAME)
        let existing = (try? ctx.fetch(allReq)) ?? []

        let entity = NSEntityDescription.entity(forEntityName: "MVModel", in: ctx)!
        let m = NSManagedObject(entity: entity, insertInto: ctx) as! MVModel
        m.videoID          = videoID
        m.videoTitle       = title
        m.thumbnailUrl     = "https://i.ytimg.com/vi/\(videoID)/hqdefault.jpg"
        m.videoTime        = "—"
        m.musicLibraryName = MV_LIST_NAME
        m.indicatoryNum    = Int16(existing.count)

        // trackNum を更新
        let libReq: NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
        libReq.predicate = NSPredicate(format: "musicLibraryName = %@", MV_LIST_NAME)
        if let lib = (try? ctx.fetch(libReq))?.first {
            lib.trackNum = Int16(existing.count + 1)
        }
        try? ctx.save()

        showToastMsg(messege: String(format: localText(key: "mv_added_fmt"), title), time: 2.5, tab: 1)
        // リロード
        viewWillAppear(false)
    }

    func makeHelpBtn() -> UIBarButtonItem {
        return .makeHelpButton(target: self, action: #selector(helpBtnTapped))
    }

    @objc func helpBtnTapped() {
        let vc = MVHowToViewController()
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        present(vc, animated: true)
    }

    func makeEditBtn() -> UIBarButtonItem{
        let button = UIButton(type: UIButton.ButtonType.system)
        button.setTitleColor(AppColor.accent, for: .normal)
        if let img = UIImage(systemName: "pencil") {
            button.setImage(img, for: .normal)
            button.tintColor = AppColor.accent
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
            button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)
        }
        button.layer.cornerRadius = 14
        button.backgroundColor = AppColor.accentMuted
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        button.addTarget(self, action: #selector(self.editDoneBtnTapped), for: .touchUpInside)
        button.titleLabel?.font = AppFont.footnote
        button.setTitle(localText(key:"btn_edit"), for: .normal)
        button.sizeToFit()
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
    // カード（youtubeView）全体の角丸をアニメーション付きで変化させる
    func applyIconCorner(cell: OKINIIRICollectionViewCell, on: Bool) {
        let fromRadius = cell.youtubeView.layer.cornerRadius
        let toRadius: CGFloat = on ? cell.bounds.width * 0.20 : 8
        let anim = CABasicAnimation(keyPath: "cornerRadius")
        anim.fromValue = fromRadius
        anim.toValue = toRadius
        anim.duration = 0.18
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cell.youtubeView.layer.cornerRadius = toRadius
        cell.youtubeView.layer.add(anim, forKey: "cornerRadius")
    }

    // iOSホーム画面風ジグルアニメーション
    func startJiggle(view: UIView) {
        guard view.layer.animation(forKey: "jiggle") == nil else { return }
        let angle = 2.8 * Double.pi / 180.0
        let anim = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        let sign: Double = Bool.random() ? 1 : -1
        anim.values = [0, sign * angle, 0, -sign * angle, 0]
        anim.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
        anim.duration = Double.random(in: 0.32...0.44)
        anim.repeatCount = .infinity
        anim.isRemovedOnCompletion = false
        anim.beginTime = CACurrentMediaTime() + Double.random(in: 0...0.25)
        view.layer.add(anim, forKey: "jiggle")
    }
    func stopJiggle(view: UIView) {
        view.layer.removeAnimation(forKey: "jiggle")
        UIView.animate(withDuration: 0.15) { view.transform = .identity }
    }
    func degreesToRadians(degrees: Float) -> Float {
        return degrees * Float(Double.pi) / 180.0
    }
    /*******************************************************************
     ボタンタップ時処理
     *******************************************************************/
    // 編集完了ボタンタップ時
    private func enterEditMode() {
        MV_SORT_ORDER_EDIT_FLG = true
        let bn = editDoneBtn.customView! as! UIButton
        editDoneBtn.title = localText(key: "home_edit_comp")
        bn.setTitle(editDoneBtn.title, for: .normal)
        bn.setImage(UIImage(systemName: "checkmark"), for: .normal)
        bn.sizeToFit()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        for i in 0..<youtubeVideoIdList.count {
            let indexPath = IndexPath(row: i, section: 0)
            if let cell = OKINIIRICollectionView.cellForItem(at: indexPath) as? OKINIIRICollectionViewCell {
                startJiggle(view: cell)
                applyIconCorner(cell: cell, on: true)
                UIView.animate(withDuration: 0.18, delay: Double(i) * 0.02, options: [], animations: {
                    cell.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
                })
                cell.deleteBtn.isHidden = false
                cell.deleteBtn.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                UIView.animate(withDuration: 0.3, delay: Double(i) * 0.02 + 0.05,
                               usingSpringWithDamping: 0.55, initialSpringVelocity: 8,
                               options: [], animations: {
                    cell.deleteBtn.transform = .identity
                })
            }
        }
    }

    @objc func editDoneBtnTapped(_ sender: Any) {
        if AVPlayerViewControllerManager.shared.controller.player != nil {
            AVPlayerViewControllerManager.shared.controller.player?.pause()
        }
        let bn = editDoneBtn.customView! as! UIButton
        if bn.title(for: .normal) == localText(key:"btn_edit") {
            enterEditMode()
        } else {
            editDoneBtn.title = localText(key:"btn_edit")
            bn.setTitle(editDoneBtn.title, for: .normal)
            bn.setImage(UIImage(systemName: "pencil"), for: .normal)
            bn.sizeToFit()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            for i in 0..<youtubeVideoIdList.count {
                let indexPath = IndexPath(row: i, section: 0)
                if let cell = OKINIIRICollectionView.cellForItem(at: indexPath) as? OKINIIRICollectionViewCell {
                    stopJiggle(view: cell)
                    applyIconCorner(cell: cell, on: false)
                    UIView.animate(withDuration: 0.18) {
                        cell.transform = .identity
                    }
                    cell.deleteBtn.isHidden = true
                }
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
                    dlog(error)
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
            let deletedVideoID = youtubeVideoIdList[index!]
            for i in 0..<mvIdFetchData.count{
                let deleteObject = mvIdFetchData[i] as MVModel
                mvIdContext.delete(deleteObject)
                dlog(deleteObject)
            }
            do{
                try mvIdContext.save()
                // サンプル動画を明示的に削除したことを記録（再シードされなくなる）
                SampleDataSeeder.markMVDeleted(videoID: deletedVideoID)
                //元の位置のデータを配列から削除する。
                youtubeVideoIdList.remove(at: index!)
                youtubeVideoTitleList.remove(at: index!)
                youtubeVideoThumbnailUrl.remove(at: index!)
                youtubeVideoTimeList.remove(at: index!)
            }catch{
                dlog(error)
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
            dlog(error)
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
    //セルサイズの指定（UICollectionViewDelegateFlowLayoutで必須）
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let totalSpacing = sectionInset * 2 + cellMargin * CGFloat(columnNum - 1)
        let width = (collectionView.frame.size.width - totalSpacing) / CGFloat(columnNum)
        cellSize = CGSize(width: width, height: width)
        return cellSize
    }
    //セル間の水平スペース
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return cellMargin
    }
    //セル間の垂直スペース
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return cellMargin
    }
    //セクションのインセット
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: sectionInset, left: sectionInset, bottom: sectionInset, right: sectionInset)
    }
    
    //セルをクリックしたら呼ばれる
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        UISelectionFeedbackGenerator().selectionChanged()
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
        guard indexPath.row < youtubeVideoIdList.count else { return }

        let videoID    = youtubeVideoIdList[indexPath.row]
        let videoTitle = youtubeVideoTitleList[indexPath.row]

        let sheet = UIAlertController(title: videoTitle, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: localText(key: "mv_play"), style: .default) { [weak self] _ in
            self?.performSegue(withIdentifier: "toYoutubePlaylistPlayer", sender: "")
        })
        sheet.addAction(UIAlertAction(title: localText(key: "mv_dictation"), style: .default) { [weak self] _ in
            guard let self else { return }
            var dummyTrack = TrackData()
            dummyTrack.title = videoTitle.isEmpty ? videoID : videoTitle
            let setupVC = DictationSetupViewController()
            setupVC.track = dummyTrack
            setupVC.youtubeVideoID = videoID
            self.navigationController?.pushViewController(setupVC, animated: true)
        })
        sheet.addAction(UIAlertAction(title: localText(key: "btn_cancel"), style: .cancel))
        if let popover = sheet.popoverPresentationController {
            if let cell = collectionView.cellForItem(at: indexPath) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            } else {
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            }
        }
        present(sheet, animated: true)
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
            if let error = error { dlog("Interstitial failed to load: \(error)"); return }
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

        // 字幕バッジ
        let vid = youtubeVideoIdList[(indexPath as NSIndexPath).row]
        cell.captionBadge.isHidden = !YoutubeCaptionStore.exists(for: vid)
        if columnNum == 2 {
            cell.youtubeVideoTitle.font = UIFont(name: "Thonburi", size: 10)
        }else if columnNum == 3 {
            cell.youtubeVideoTitle.font = UIFont(name: "Thonburi", size: 7)
        }
        // 画像の表示調整（awakeFromNib で設定済み）
        //imgUrlStringをNSURL型に変換
        let imgUrl: NSURL = NSURL(string: youtubeVideoThumbnailUrl[(indexPath as NSIndexPath).row])!
        //画像データに変換
        cell.youtubeVideoThumbnail.sd_setImage(with: imgUrl as URL)
        
        // 編集状態を MV_SORT_ORDER_EDIT_FLG だけで判断（二重制御を排除）
        cell.deleteBtn.tag = (indexPath as NSIndexPath).row
        if MV_SORT_ORDER_EDIT_FLG {
            startJiggle(view: cell)
            cell.youtubeView.layer.cornerRadius = cell.bounds.width * 0.20
            cell.youtubeView.clipsToBounds = true
            cell.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            // アニメなしで確実に表示（ドラッグ中の再利用でもスケール0で止まらない）
            cell.deleteBtn.isHidden = false
            cell.deleteBtn.transform = .identity
            cell.deleteBtn.alpha = 1
        } else {
            stopJiggle(view: cell)
            cell.youtubeView.layer.cornerRadius = 8
            cell.youtubeView.clipsToBounds = true
            cell.transform = .identity
            cell.deleteBtn.isHidden = true
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
                dlog(error)
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
            enterEditMode()
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


