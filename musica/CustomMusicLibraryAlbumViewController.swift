//
//  CustomMusicLibraryViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2017/05/02.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import MediaPlayer

class CustomMusicLibraryAlbumViewController: UIViewController , UITableViewDataSource, UITableViewDelegate ,MPMediaPickerControllerDelegate {
    @IBOutlet weak var listModeSegment: UISegmentedControl!
    @IBOutlet weak var musicAccessErrView: UIView!
    @IBOutlet weak var OSAlbumtableview: UITableView!
    @IBOutlet weak var noPlayListLbl: UILabel!
    @IBOutlet weak var footerDammyView: UIView!
    @IBOutlet weak var footerHeight: NSLayoutConstraint!

    var OSAlbumList: [AlbumData] = []
    var OSLibraryList: [AlbumData] = []
    var Album: AlbumData = AlbumData()

    // 画面遷移時データ受け渡し用
    var albumSelectIndex = 0
    var osAlbumDataList : [AlbumData] = []
    var osLibraryDataList : [AlbumData] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = localText(key: "library_select_album_title")
        navigationItem.largeTitleDisplayMode = .always
        OSAlbumtableview.tableHeaderView = makeLibraryGuideCard(
            step: 1, total: 3,
            icon: "music.note.list",
            title: "アルバムまたはプレイリストを選択",
            body: "練習したい曲が入っているアルバムをタップしてください。上部のセグメントでプレイリストに切り替えられます。"
        )
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
                        
                        dlog("artist:NILL")
                        break
                    }
                    OSAlbumList[_albumIndex].trackData[trackIndex].artist = artist as! String
                    dlog("artist: \(OSAlbumList[_albumIndex].trackData[trackIndex].artist)")
                    
                    // 楽曲のタイトル
                    guard let title = song.value(forProperty: MPMediaItemPropertyTitle) else {
                        
                        dlog("title:NILL")
                        break
                    }
                    OSAlbumList[_albumIndex].trackData[trackIndex].title = title as! String
                    dlog("title: \(OSAlbumList[_albumIndex].trackData[trackIndex].title)")
                    
                    // 楽曲の歌詞
                    guard let lyric = song.value(forProperty: MPMediaItemPropertyLyrics) else {
                        
                        dlog("lyric:NILL")
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
                        dlog("artist:NILL")
                        break
                    }
                    OSLibraryList[albumIndex].trackData[trackIndex].artist = artist as! String
                    dlog("artist: \(OSLibraryList[albumIndex].trackData[trackIndex].artist)")
                    
                    // 楽曲のタイトル
                    guard let title = song.value(forProperty: MPMediaItemPropertyTitle) else {
                        dlog("title:NILL")
                        break
                    }
                    OSLibraryList[albumIndex].trackData[trackIndex].title = title as! String
                    dlog("title: \(OSLibraryList[albumIndex].trackData[trackIndex].title)")
                    
                    // 楽曲の歌詞
                    guard let lyric = song.value(forProperty: MPMediaItemPropertyLyrics) else {
                        dlog("lyric:NILL")
                        break
                    }
                    OSLibraryList[albumIndex].trackData[trackIndex].lyric = lyric as! String
                    dlog("lyric: \(OSLibraryList[albumIndex].trackData[trackIndex].lyric)")
                    
                    //曲のパス
                    let path = song.assetURL ?? nil
                    
                    OSLibraryList[albumIndex].trackData[trackIndex].url = path
                    
                    // path が存在するトラックは、フラグを立てる
                    OSLibraryList[albumIndex].trackData[trackIndex].existFlg = true
                    OSLibraryList[albumIndex].existFlg = true
                    
                    dlog("path: \(String(describing: OSLibraryList[albumIndex].trackData[trackIndex].url))")
                    
                    //ジャンル
                    guard let genre = song.value(forProperty: MPMediaItemPropertyGenre) else {
                        dlog("genre:NILL")
                        break
                    }
                    OSLibraryList[albumIndex].trackData[trackIndex].genre = genre as! String
                    dlog("genre: \(OSLibraryList[albumIndex].trackData[trackIndex].genre)")

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
        self.navigationController?.navigationBar.prefersLargeTitles = true
        if #available(iOS 15.0, *) {
            let navColor  = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
            let textColor = NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = navColor
            appearance.titleTextAttributes      = [.foregroundColor: textColor]
            appearance.largeTitleTextAttributes = [.foregroundColor: textColor]
            self.navigationController!.navigationBar.standardAppearance   = appearance
            self.navigationController!.navigationBar.scrollEdgeAppearance = appearance
            self.navigationController!.navigationBar.tintColor = AppColor.accent
        } else {
            self.navigationController?.navigationBar.barTintColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
            self.navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]]
            self.navigationController!.navigationBar.tintColor = AppColor.accent
        }

        selectBannerView.isHidden = true
        selectMusicView.frame = CGRect(x: 0, y: Int(myAppFrameSize.height - footerDammyView.frame.size.height - getTabHeghtPlusSafeArea()), width: Int(myAppFrameSize.width), height: Int(footerDammyView.frame.size.height))
        updateFooterAppearance()
        OSAlbumtableview.translatesAutoresizingMaskIntoConstraints = false
        footerHeight.constant = -92
        OSAlbumtableview.reloadData()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if selectMusicViewMakeFlg {
            updateFooterAppearance()
        } else {
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
        selectMusicView.frame = CGRect(x: 0, y: Int(myAppFrameSize.height - footerDammyView.frame.size.height - getTabHeghtPlusSafeArea()), width: Int(myAppFrameSize.width), height: Int(footerDammyView.frame.size.height))
        selectMusicView.isUserInteractionEnabled = true

        selectMusicLabel.font = AppFont.subheadline
        selectMusicLabel.sizeToFit()
        selectMusicLabel.layer.position = CGPoint(x: Int(myAppFrameSize.width) / 2, y: 22)

        selectMusicButton.setTitle("次へ →", for: .normal)
        selectMusicButton.frame = CGRect(x: 0, y: 0, width: 200, height: 44)
        selectMusicButton.setTitleColor(.white, for: .normal)
        selectMusicButton.titleLabel?.font = AppFont.button
        selectMusicButton.layer.cornerRadius = 14
        selectMusicButton.layer.position = CGPoint(x: Int(myAppFrameSize.width) / 2, y: 62)

        if !selectMusicViewMakeFlg {
            selectMusicView.contentView.addSubview(selectMusicLabel)
            selectMusicView.contentView.addSubview(selectMusicButton)
        }
        selectMusicViewMakeFlg = true
        updateFooterAppearance()
        return selectMusicView
    }

    private func updateFooterAppearance() {
        let hasSelection = selectedTracks.count > 0
        selectMusicLabel.text = String(selectedTracks.count) + localText(key: "musiclibrary_selected_track_num")
        selectMusicLabel.textColor = hasSelection ? AppColor.accent : AppColor.textDisabled
        selectMusicButton.backgroundColor = hasSelection ? AppColor.accent : AppColor.inactive
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
            self.title = localText(key: "library_select_album_title")
            showToastMsg(messege:LISTMODE_ALBUM_MSG,time:2.0, tab: COLOR_THEMA.HOME.rawValue,setVc:self,Hposi:32)
        case 1:
            self.title = localText(key: "library_select_playlist_title")
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
