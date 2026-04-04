//
//  CustomMusicLibraryViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2017/05/02.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import MediaPlayer
import GoogleMobileAds

class CustomMusicLibraryAlbumViewController: UIViewController , UITableViewDataSource, UITableViewDelegate ,MPMediaPickerControllerDelegate {
    @IBOutlet weak var listModeSegment: UISegmentedControl!
    @IBOutlet weak var musicAccessErrView: UIView!
    @IBOutlet weak var OSAlbumtableview: UITableView!
    // MusicLibrary一覧に表示するデータ
    @IBOutlet weak var noPlayListLbl: UILabel!
    @IBOutlet weak var footerDammyView: UIView!
    
    @IBOutlet weak var footerHeight: NSLayoutConstraint!
    var OSAlbumList: [AlbumData] = []
    var OSLibraryList: [AlbumData] = []
    var Album: AlbumData = AlbumData()
    var bannerViewHeight = 92
    var footerB = 0
    
    // 画面遷移時データ受け渡し用
    var albumSelectIndex = 0
    var osAlbumDataList : [AlbumData] = []
    var osLibraryDataList : [AlbumData] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        setMusicDataToAPLData()
        if CUSTOM_LYBRARY_FROM_MUSICLIST {
            nowTrackListCheck()
        }
    }
    /*******************************************************************
     共通処理
     *******************************************************************/
    /* 選択済みの音楽取得　*/
    func nowTrackListCheck() {
        selectedTracks = [:]
        for var track in displayMusicLibraryData.trackData {
            if track.url == nil {
                continue
            }
            let key = "\(String(describing: track.url))"
            // selectedTracks を全て true へ
            selectedTracks[key]=true
            track.checkedFlg=true
        }
    }
    /*******************************************************************
     音楽データの取得処理
     *******************************************************************/
    var _index = 0
    func setMusicDataToAPLData(){
        noPlayListLbl.isHidden = true
        let albumListQuery = MPMediaQuery.albums()
        let lybraryListQuery = MPMediaQuery.playlists()
        if let albums = albumListQuery.collections {
            get_Album_Info : for (albumIndex,album) in albums.enumerated() {
                // Album内のトラックを示すインデックス
                var trackIndex = 0
                var _albumIndex = 0
                if DEBUG_FLG {
                    _albumIndex = albumIndex - _index
                }else{
                    _albumIndex = albumIndex
                }
                OSAlbumList.append(AlbumData())
                OSAlbumList[_albumIndex].title = album.representativeItem?.albumTitle! ?? "NO ALBUM NAME"
                OSAlbumList[_albumIndex].artwork = album.representativeItem?.artwork
                OSAlbumList[_albumIndex].artist = album.representativeItem?.albumArtist ?? "NO ARTIST DATA"
                
                for song in album.items {
                    OSAlbumList[_albumIndex].trackData.append(TrackData())
                    OSAlbumList[_albumIndex].trackData[trackIndex].artist = ""
                    OSAlbumList[_albumIndex].trackData[trackIndex].albumName = OSAlbumList[_albumIndex].title!
                    OSAlbumList[_albumIndex].trackData[trackIndex].albumArtistName = OSAlbumList[_albumIndex].artist!
                    OSAlbumList[_albumIndex].trackData[trackIndex].artworkImg = OSAlbumList[_albumIndex].artwork?.image(at: (OSAlbumList[_albumIndex].artwork?.bounds.size)!)
                    
                    // アーティスト名
                    guard let artist = song.value(forProperty: MPMediaItemPropertyArtist) else {
                        
                        print("artist:NILL")
                        break
                    }
                    OSAlbumList[_albumIndex].trackData[trackIndex].artist = artist as! String
                    print("artist: \(OSAlbumList[_albumIndex].trackData[trackIndex].artist)")
                    
                    // 楽曲のタイトル
                    guard let title = song.value(forProperty: MPMediaItemPropertyTitle) else {
                        
                        print("title:NILL")
                        break
                    }
                    OSAlbumList[_albumIndex].trackData[trackIndex].title = title as! String
                    print("title: \(OSAlbumList[_albumIndex].trackData[trackIndex].title)")
                    
                    // 楽曲の歌詞
                    guard let lyric = song.value(forProperty: MPMediaItemPropertyLyrics) else {
                        
                        print("lyric:NILL")
                        break
                    }
                    OSAlbumList[_albumIndex].trackData[trackIndex].lyric = lyric as! String
                    //曲のパス
                    let path = song.assetURL ?? nil
                    
                    OSAlbumList[_albumIndex].trackData[trackIndex].url = path
                    OSAlbumList[_albumIndex].trackData[trackIndex].existFlg = true
                    OSAlbumList[_albumIndex].existFlg = true
                    //ジャンル
                    guard let genre = song.value(forProperty: MPMediaItemPropertyGenre) else {
                        break
                    }
                    OSAlbumList[_albumIndex].trackData[trackIndex].genre = genre as! String
                    // チェック状態の取得
                    let key = "\(String(describing: OSAlbumList[_albumIndex].trackData[trackIndex].url))"
                    
                    
                    if let selected = selectedTracks[key]{
                        OSAlbumList[_albumIndex].trackData[trackIndex].checkedFlg = selected
                    }else{
                        OSAlbumList[_albumIndex].trackData[trackIndex].checkedFlg = false
                    }
                    // iCloud上のものか確認
                    guard let isCloudItem = song.value(forProperty: MPMediaItemPropertyIsCloudItem) else {
                        break
                    }
                    OSAlbumList[_albumIndex].trackData[trackIndex].isCloudItem = isCloudItem as! Bool
                    // track のインクリメント
                    trackIndex = trackIndex + 1
                }
            }
        }
        if let librarys = lybraryListQuery.collections {
            get_Library_Info : for (albumIndex,library) in librarys.enumerated() {
                // Album内のトラックを示すインデックス
                var trackIndex = 0
                OSLibraryList.append(AlbumData())
                let  playlist = library as! MPMediaPlaylist
                OSLibraryList[albumIndex].title = playlist.name!
                OSLibraryList[albumIndex].artwork = library.representativeItem?.artwork
                OSLibraryList[albumIndex].artist = "DEVICE Play List"//library.representativeItem?.albumArtist ?? "NO ARTIST DATA"
                
                for song in library.items {
                    OSLibraryList[albumIndex].trackData.append(TrackData())
                    OSLibraryList[albumIndex].trackData[trackIndex].artist = ""
                    OSLibraryList[albumIndex].trackData[trackIndex].albumName = OSLibraryList[albumIndex].title!
                    OSLibraryList[albumIndex].trackData[trackIndex].albumArtistName = OSLibraryList[albumIndex].artist!

                    let artworkImg = song.artwork?.image(at: (song.artwork?.bounds.size)!)
                    if artworkImg != nil {
                        OSLibraryList[albumIndex].trackData[trackIndex].artworkImg = artworkImg
                    }
                    
                    // アーティスト名　album.representativeItem?.artwork
                    guard let artist = song.value(forProperty: MPMediaItemPropertyArtist) else {
                        print("artist:NILL")
                        break
                    }
                    OSLibraryList[albumIndex].trackData[trackIndex].artist = artist as! String
                    print("artist: \(OSLibraryList[albumIndex].trackData[trackIndex].artist)")
                    
                    // 楽曲のタイトル
                    guard let title = song.value(forProperty: MPMediaItemPropertyTitle) else {
                        print("title:NILL")
                        break
                    }
                    OSLibraryList[albumIndex].trackData[trackIndex].title = title as! String
                    print("title: \(OSLibraryList[albumIndex].trackData[trackIndex].title)")
                    
                    // 楽曲の歌詞
                    guard let lyric = song.value(forProperty: MPMediaItemPropertyLyrics) else {
                        print("lyric:NILL")
                        break
                    }
                    OSLibraryList[albumIndex].trackData[trackIndex].lyric = lyric as! String
                    print("lyric: \(OSLibraryList[albumIndex].trackData[trackIndex].lyric)")
                    
                    //曲のパス
                    let path = song.assetURL ?? nil
                    
                    OSLibraryList[albumIndex].trackData[trackIndex].url = path
                    
                    // path が存在するトラックは、フラグを立てる
                    OSLibraryList[albumIndex].trackData[trackIndex].existFlg = true
                    OSLibraryList[albumIndex].existFlg = true
                    
                    print("path: \(String(describing: OSLibraryList[albumIndex].trackData[trackIndex].url))")
                    
                    //ジャンル
                    guard let genre = song.value(forProperty: MPMediaItemPropertyGenre) else {
                        print("genre:NILL")
                        break
                    }
                    OSLibraryList[albumIndex].trackData[trackIndex].genre = genre as! String
                    print("genre: \(OSLibraryList[albumIndex].trackData[trackIndex].genre)")

                    // チェック状態の取得
                    let key = "\(String(describing: OSLibraryList[albumIndex].trackData[trackIndex].url))"
                    
                    if let selected = selectedTracks[key]{
                        OSLibraryList[albumIndex].trackData[trackIndex].checkedFlg = selected
                    }else{
                        OSLibraryList[albumIndex].trackData[trackIndex].checkedFlg = false
                    }
                    
                    // iCloud上のものか確認
                    guard let isCloudItem = song.value(forProperty: MPMediaItemPropertyIsCloudItem) else {
                        break
                    }
                    OSLibraryList[albumIndex].trackData[trackIndex].isCloudItem = isCloudItem as! Bool
                    // track のインクリメント
                    trackIndex = trackIndex + 1
                }
            }
        }
    }
    
    /*******************************************************************
     画面描画時の処理
     *******************************************************************/
    override func viewWillAppear(_ animated: Bool) {
        if #available(iOS 13.0, *), IOS13_RESIST_FLG{
            IOS13_RESIST_FLG = false
            self.navigationController?.popToRootViewController(animated: true)
            return
        }
        super.viewWillAppear(animated)

        selectMusicView.isHidden = false
        // navigationbarの色設定
        selectMusicButton.addTarget(self, action: #selector(self.toRegistMusicLibrary), for: UIControl.Event.touchUpInside)
        self.navigationController?.navigationBar.isTranslucent = false
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
        
        bannerViewHeight = 92
        if ADApearFlg() {
            if AD_DISPLAY_MUSIC_REGISTER_ALBUM_BANNER {
//                // AdMobバナー広告の読み込み
                selectBannerView.translatesAutoresizingMaskIntoConstraints = true
                selectBannerView.layer.position = CGPoint(x:Int(myAppFrameSize.width)/2, y:112)
                selectBannerView.adUnitID = ADMOB_BANNER_ADUNIT_ID
                selectBannerView.load(GADRequest())
                selectBannerView.isHidden = false
                selectBannerView.rootViewController = self
                
//                custumLoadBannerAd(bannerView: selectBannerView,setBannerView:selectMusicView)
//                OSAlbumtableview.reloadData()
//                addBannerViewToView(selectBannerView)
                bannerViewHeight = bannerViewHeight + Int(selectBannerView.frame.height)
                footerB = Int(selectBannerView.frame.height)
            }else{
                selectBannerView.isHidden = true
            }
        }else{
            selectBannerView.isHidden = true
        }
        selectMusicView.frame = CGRect(x: 0, y: Int(myAppFrameSize.height - footerDammyView.frame.size.height - getTabHeghtPlusSafeArea())  - footerB , width: Int(myAppFrameSize.width),height: Int(footerDammyView.frame.size.height) + footerB)
        // Label,Buttonを作成.
        selectMusicLabel.text = String(selectedTracks.count) + localText(key:"musiclibrary_selected_track_num")
        if selectedTracks.count == 0 {
            selectMusicLabel.textColor = UIColor.lightGray
            selectMusicButton.backgroundColor = UIColor.lightGray
        }else{
            selectMusicLabel.textColor = UIColor(red: 0, green: 122 / 255, blue: 1,alpha: 1)
            selectMusicButton.backgroundColor = UIColor.systemBlue
        }
        selectMusicLabel.font = UIFont.boldSystemFont(ofSize: CGFloat(18))
        selectMusicLabel.sizeToFit()
        selectMusicLabel.layer.position = CGPoint(x:Int(myAppFrameSize.width)/2, y:22)
        OSAlbumtableview.translatesAutoresizingMaskIntoConstraints = false
        footerHeight.constant = -CGFloat(bannerViewHeight)
        OSAlbumtableview.reloadData()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if selectedTracks.count == 0 {
            selectMusicLabel.textColor = UIColor.lightGray
            selectMusicButton.backgroundColor = UIColor.lightGray
        }else{
            selectMusicLabel.textColor = UIColor(red: 0, green: 122 / 255, blue: 1,alpha: 1)
            selectMusicButton.backgroundColor = UIColor.systemBlue
        }
        if selectMusicViewMakeFlg {
            
        }else{
            let window = UIApplication.shared.keyWindow!
            window.addSubview(createFooterView())
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // セクションの個数
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    // tableフッダーの高さをかえします。
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    func createFooterView() -> UIView {
//        if isDarkMode(vc:self){
//            selectMusicView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
//        }
        selectMusicView.frame = CGRect(x: 0, y: Int(myAppFrameSize.height - footerDammyView.frame.size.height - getTabHeghtPlusSafeArea())  - footerB , width: Int(myAppFrameSize.width),height: Int(footerDammyView.frame.size.height) + footerB)
        selectMusicView.isUserInteractionEnabled = true
        // Label,Buttonを作成.
        selectMusicLabel.text = String(selectedTracks.count) + localText(key:"musiclibrary_selected_track_num")
        if selectedTracks.count == 0 {
            selectMusicLabel.textColor = UIColor.lightGray
            selectMusicButton.backgroundColor = UIColor.lightGray
        }else{
            selectMusicLabel.textColor = UIColor(red: 0, green: 122 / 255, blue: 1,alpha: 1)
            selectMusicButton.backgroundColor = UIColor.systemBlue
        }
        selectMusicLabel.font = UIFont.boldSystemFont(ofSize: CGFloat(18))
        selectMusicLabel.sizeToFit()
        selectMusicLabel.layer.position = CGPoint(x:Int(myAppFrameSize.width)/2, y:22)
        
        // ボタンを押した時に実行するメソッドを指定
        selectMusicButton.setTitle("登録する", for: UIControl.State.normal)
        selectMusicButton.frame = CGRect(x: 0, y: 0, width: 200, height: 40)
        selectMusicButton.setTitleColor(UIColor.white, for: UIControl.State.normal)
        selectMusicButton.titleLabel?.font = UIFont.init(name: "Helvetica-Bold", size: 15)
        selectMusicButton.layer.cornerRadius = 10
        selectMusicButton.layer.position = CGPoint(x:Int(myAppFrameSize.width)/2, y:64)
        if selectMusicViewMakeFlg == false{
            selectMusicView.contentView.addSubview(selectMusicLabel)
            selectMusicView.contentView.addSubview(selectMusicButton)
            selectMusicView.contentView.addSubview(selectBannerView)
        }
        selectMusicViewMakeFlg = true
        
        return selectMusicView
    }
    // tableフッターにViewをセットしてかえします。
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    // セクション内の行数
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if listModeSegment.selectedSegmentIndex == 0 {
            // Listの値の個数
            noPlayListLbl.isHidden = true
            if OSAlbumList.count == 0 {
                musicAccessErrView.isHidden = false
                selectMusicView.isHidden = true
            }else{
                musicAccessErrView.isHidden = true
                selectMusicView.isHidden = false
            }
            return OSAlbumList.count

        }else{
            // Listの値の個数
            if OSLibraryList.count == 0 {
                musicAccessErrView.isHidden = true
                noPlayListLbl.isHidden = false
            }else{
                musicAccessErrView.isHidden = true
                noPlayListLbl.isHidden = true
            }
            return OSLibraryList.count
        }
    }
    // セルを作る
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // テーブルのセルを参照する
        let cell = tableView.dequeueReusableCell(withIdentifier: "AlbumData", for: indexPath)  as!CustomAlbumListTableViewCell
        if listModeSegment.selectedSegmentIndex == 0 {
            let AlbumData = OSAlbumList[(indexPath as NSIndexPath).row]
            // セルに値を設定
            cell.setCell(titleText: AlbumData.title!,descriptionText: AlbumData.artist!)

            // アートワーク表示
            if let artwork = AlbumData.artwork {
                let image = artwork.image(at: cell.AlbumImage.bounds.size)
                cell.AlbumImage.contentMode = .scaleAspectFit
                cell.AlbumImage.layer.cornerRadius = ICON_CORNER_RADIUS_SETTINMGS
                cell.AlbumImage.layer.borderWidth = ICON_BORDERWIDTH
                cell.AlbumImage.image = image
            } else {
                // アートワークがないとき (灰色表示)
                cell.AlbumImage.image = nil
                cell.AlbumImage.backgroundColor = UIColor.gray
                cell.AlbumImage.layer.borderColor = UIColor.gray.cgColor
            }
        } else {
            let LibraryData = OSLibraryList[(indexPath as NSIndexPath).row]
            // セルに値を設定
            cell.setCell(titleText: LibraryData.title!,descriptionText: LibraryData.artist!)

            // アートワーク表示
            if let artwork = LibraryData.artwork {
                let image = artwork.image(at: cell.AlbumImage.bounds.size)
                cell.AlbumImage.contentMode = .scaleAspectFit
                cell.AlbumImage.layer.cornerRadius = ICON_CORNER_RADIUS_SETTINMGS
                cell.AlbumImage.layer.borderWidth = ICON_BORDERWIDTH
                cell.AlbumImage.image = image
            } else {
                // アートワークがないとき (灰色表示)
                cell.AlbumImage.image = nil
                cell.AlbumImage.backgroundColor = UIColor.gray
                cell.AlbumImage.layer.borderColor = UIColor.gray.cgColor
            }
        }
        fadeInRanDomAnimesion(view : cell.AlbumImage)
        return cell
    }
    
    /* UITableViewDelegateデリゲートメソッド */
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath as IndexPath, animated: true)

        albumSelectIndex = indexPath.row
        if listModeSegment.selectedSegmentIndex == 0 {
            if OSAlbumList[indexPath.row].trackData.count == 0{
                let alert = UIAlertController(title: MESSAGE_NONE_TITLE, message: MESSAGE_NONE_MUSIC_BODY, preferredStyle: UIAlertController.Style.alert)
                let okayButton = UIAlertAction(title: MESSAGE_OK, style: UIAlertAction.Style.cancel, handler: nil)
                alert.addAction(okayButton)
                present(alert, animated: true, completion: nil)
                return
            }
        }else{
            if OSLibraryList[indexPath.row].trackData.count == 0{
                let alert = UIAlertController(title: MESSAGE_NONE_TITLE, message: MESSAGE_NONE_LIBRARY_BODY, preferredStyle: UIAlertController.Style.alert)
                let okayButton = UIAlertAction(title: MESSAGE_OK, style: UIAlertAction.Style.cancel, handler: nil)
                alert.addAction(okayButton)
                present(alert, animated: true, completion: nil)
                return
            }
        }
        performSegue(withIdentifier: "toTrackList",sender: "")
        
    }
    @objc func toRegistMusicLibrary(){
        if selectedTracks.count > 0 {
            osAlbumDataList = OSAlbumList
            osLibraryDataList = OSLibraryList
            performSegue(withIdentifier: "toMusicLibraryRegist", sender: "")
        }else{
            showToastMsg(messege:LISTMODE_LIVRARY_NOSELECTED,time:2.0, tab: COLOR_THEMA.HOME.rawValue)
        }
    }
    
    /*
     　画面遷移時の処理
     */
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        //Track 一覧画面へ
        if segue.identifier == "toTrackList" {
            // CustomMusicLibraryTrackViewControllerをインスタンス化
            let secondVc = segue.destination as! CustomMusicLibraryTrackViewController
            // 値を渡す
            secondVc.listModeSegment = listModeSegment.selectedSegmentIndex
            secondVc.albumSelectIndex = albumSelectIndex
            secondVc.osAlbumDataList = OSAlbumList
            secondVc.osLibraryDataList = OSLibraryList
            if listModeSegment.selectedSegmentIndex == 0 {
                secondVc.osTrackDataList = OSAlbumList
            }else{
                secondVc.osTrackDataList = OSLibraryList
            }
            
        } else if segue.identifier == "toMusicLibraryRegist" {
            // CustamMusicLibraryRegisterViewControllerをインスタンス化
            let secondVc = segue.destination as! CustamMusicLibraryRegisterViewController
            secondVc.listModeSegment = listModeSegment.selectedSegmentIndex
            // 値を渡す
            secondVc.osAlbumDataList = OSAlbumList
            secondVc.osLibraryDataList = OSLibraryList
        }
    }
    
    @IBAction func listModeSegmentChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            showToastMsg(messege:LISTMODE_ALBUM_MSG,time:2.0, tab: COLOR_THEMA.HOME.rawValue,setVc:self,Hposi:32)
        case 1:
            showToastMsg(messege:LISTMODE_LIVRARY_MSG,time:2.0, tab: COLOR_THEMA.HOME.rawValue,setVc:self,Hposi:32)
        default:
            break
        }
        OSAlbumtableview.reloadData()
    }
    
    @IBAction func forSettingAPPBtnTapped(_ sender: Any) {
        UIApplication.shared.open(NSURL(string: UIApplication.openSettingsURLString)! as URL)
    }

}
