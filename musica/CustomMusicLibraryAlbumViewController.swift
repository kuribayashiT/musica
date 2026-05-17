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

    // セグメントを section header として保持（removeFromSuperview 後に再利用）
    private var segmentHeaderView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = localText(key: "library_select_album_title")
        navigationItem.largeTitleDisplayMode = .always
        extendedLayoutIncludesOpaqueBars = true

        // セグメントをストーリーボード位置から外し、section header として使う
        // → tableView が画面上端まで届き、ラージタイトルのスクロール折りたたみが機能する
        listModeSegment.removeFromSuperview()
        listModeSegment.translatesAutoresizingMaskIntoConstraints = false
        let segWrapper = UIView()
        segWrapper.backgroundColor = AppColor.surface
        segWrapper.addSubview(listModeSegment)
        NSLayoutConstraint.activate([
            listModeSegment.topAnchor.constraint(equalTo: segWrapper.topAnchor, constant: 8),
            listModeSegment.bottomAnchor.constraint(equalTo: segWrapper.bottomAnchor, constant: -8),
            listModeSegment.leadingAnchor.constraint(equalTo: segWrapper.leadingAnchor, constant: 16),
            listModeSegment.trailingAnchor.constraint(equalTo: segWrapper.trailingAnchor, constant: -16),
        ])
        segmentHeaderView = segWrapper

        // tableView を画面上端まで伸ばす（ラージタイトルのスクロール折りたたみに必要）
        OSAlbumtableview.translatesAutoresizingMaskIntoConstraints = false
        view.constraints.first(where: {
            ($0.firstItem as? UIView == OSAlbumtableview && $0.firstAttribute == .top) ||
            ($0.secondItem as? UIView == OSAlbumtableview && $0.secondAttribute == .top)
        })?.isActive = false
        OSAlbumtableview.topAnchor.constraint(equalTo: view.topAnchor).isActive = true

        // iOS 15+ のセクションヘッダー上部パディングを除去
        if #available(iOS 15.0, *) {
            OSAlbumtableview.sectionHeaderTopPadding = 0
        }

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
                    guard let title = song.value(forProperty: MPMediaItemPropertyTitle) as? String,
                          !title.isEmpty else { continue }
                    var track = TrackData()
                    track.albumName       = OSAlbumList[_albumIndex].title!
                    track.albumArtistName = OSAlbumList[_albumIndex].artist!
                    if let aw = OSAlbumList[_albumIndex].artwork {
                        track.artworkImg = aw.image(at: aw.bounds.size)
                    }
                    track.title             = title
                    track.artist            = song.value(forProperty: MPMediaItemPropertyArtist) as? String ?? ""
                    track.lyric             = song.value(forProperty: MPMediaItemPropertyLyrics) as? String ?? ""
                    track.genre             = song.value(forProperty: MPMediaItemPropertyGenre) as? String ?? ""
                    track.url               = song.assetURL
                    track.hasProtectedAsset = song.hasProtectedAsset
                    track.persistentID      = song.persistentID
                    track.isCloudItem       = song.value(forProperty: MPMediaItemPropertyIsCloudItem) as? Bool ?? false
                    track.existFlg          = true
                    track.checkedFlg        = selectedTracks[track.selectionKey] ?? false
                    OSAlbumList[_albumIndex].trackData.append(track)
                    OSAlbumList[_albumIndex].existFlg = true
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
                    guard let title = song.value(forProperty: MPMediaItemPropertyTitle) as? String,
                          !title.isEmpty else { continue }
                    var track = TrackData()
                    track.albumName       = OSLibraryList[albumIndex].title!
                    track.albumArtistName = OSLibraryList[albumIndex].artist!
                    if let aw = song.artwork { track.artworkImg = aw.image(at: aw.bounds.size) }
                    track.title             = title
                    track.artist            = song.value(forProperty: MPMediaItemPropertyArtist) as? String ?? ""
                    track.lyric             = song.value(forProperty: MPMediaItemPropertyLyrics) as? String ?? ""
                    track.genre             = song.value(forProperty: MPMediaItemPropertyGenre) as? String ?? ""
                    track.url               = song.assetURL
                    track.hasProtectedAsset = song.hasProtectedAsset
                    track.persistentID      = song.persistentID
                    track.isCloudItem       = song.value(forProperty: MPMediaItemPropertyIsCloudItem) as? Bool ?? false
                    track.existFlg          = true
                    track.checkedFlg        = selectedTracks[track.selectionKey] ?? false
                    OSLibraryList[albumIndex].trackData.append(track)
                    OSLibraryList[albumIndex].existFlg = true
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
        // ラージタイトルのスクロール折りたたみに必要（translucent にすることでスクロールビューが nav bar の下まで延びる）
        self.navigationController?.navigationBar.isTranslucent = true
        self.navigationController?.navigationBar.prefersLargeTitles = true
        if #available(iOS 15.0, *) {
            let navColor  = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
            let textColor = NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = navColor
            appearance.titleTextAttributes      = [.foregroundColor: textColor]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
            self.navigationController!.navigationBar.standardAppearance   = appearance
            self.navigationController!.navigationBar.scrollEdgeAppearance = appearance
            self.navigationController!.navigationBar.tintColor = AppColor.accent
        } else {
            self.navigationController?.navigationBar.barTintColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
            self.navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]]
            self.navigationController!.navigationBar.tintColor = AppColor.accent
        }

        selectBannerView.isHidden = true
        let tabH = tabBarController?.tabBar.frame.height ?? getTabHeghtPlusSafeArea()
        let footerH: CGFloat = 76
        selectMusicView.frame = CGRect(x: 0, y: Int(myAppFrameSize.height - footerH - tabH), width: Int(myAppFrameSize.width), height: Int(footerH))
        updateFooterAppearance()
        footerHeight.constant = -footerH
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
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        selectMusicView.isHidden = true
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // セクションの個数
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    // セグメントコントロールを sticky な section header として表示
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return segmentHeaderView
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 52
    }

    // tableフッダーの高さをかえします。
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    func createFooterView() -> UIView {
        let tabH = tabBarController?.tabBar.frame.height ?? getTabHeghtPlusSafeArea()
        let footerH: CGFloat = 76
        selectMusicView.frame = CGRect(x: 0, y: Int(myAppFrameSize.height - footerH - tabH), width: Int(myAppFrameSize.width), height: Int(footerH))
        selectMusicView.isUserInteractionEnabled = true

        selectMusicLabel.font = AppFont.subheadline
        selectMusicLabel.sizeToFit()
        selectMusicLabel.layer.position = CGPoint(x: Int(myAppFrameSize.width) / 2, y: 16)

        selectMusicButton.setTitle("次へ →", for: .normal)
        selectMusicButton.frame = CGRect(x: 0, y: 0, width: 200, height: 44)
        selectMusicButton.setTitleColor(.white, for: .normal)
        selectMusicButton.titleLabel?.font = AppFont.button
        selectMusicButton.layer.cornerRadius = 14
        selectMusicButton.layer.position = CGPoint(x: Int(myAppFrameSize.width) / 2, y: 52)

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
                let s = cell.AlbumImage.bounds.size.width > 0 ? cell.AlbumImage.bounds.size : CGSize(width: 60, height: 60)
                cell.AlbumImage.image = playlistThumbnail(name: LibraryData.title ?? "", size: s)
                cell.AlbumImage.contentMode = .scaleAspectFill
                cell.AlbumImage.backgroundColor = .clear
                cell.AlbumImage.layer.cornerRadius = ICON_CORNER_RADIUS_SETTINMGS
                cell.AlbumImage.layer.borderWidth = ICON_BORDERWIDTH
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

    // プレイリスト名からテーマカラー＋アイコンでサムネイルを生成する
    private func playlistThumbnail(name: String, size: CGSize) -> UIImage {
        struct Theme { let top: UIColor; let bottom: UIColor; let symbol: String }
        func hsl(_ h: CGFloat, _ s: CGFloat, _ b: CGFloat) -> UIColor {
            UIColor(hue: h / 360, saturation: s, brightness: b, alpha: 1)
        }
        let n = name.lowercased()
        let theme: Theme
        if n.contains("クラシック") || n.contains("classic") {
            theme = Theme(top: hsl(36, 0.70, 0.52), bottom: hsl(48, 0.60, 0.78), symbol: "music.note")
        } else if n.contains("最近再生") || n.contains("recently played") {
            theme = Theme(top: hsl(210, 0.75, 0.45), bottom: hsl(220, 0.55, 0.72), symbol: "clock.fill")
        } else if n.contains("最近追加") || n.contains("recently added") {
            theme = Theme(top: hsl(148, 0.70, 0.38), bottom: hsl(160, 0.55, 0.65), symbol: "plus.circle.fill")
        } else if n.contains("トップレート") || n.contains("top rated") {
            theme = Theme(top: hsl(350, 0.75, 0.48), bottom: hsl(10, 0.60, 0.72), symbol: "star.fill")
        } else if n.contains("トップ") || n.contains("top") {
            theme = Theme(top: hsl(22, 0.80, 0.48), bottom: hsl(38, 0.65, 0.74), symbol: "flame.fill")
        } else if n.contains("90年代") || n.contains("90s") || n.contains("'90") {
            theme = Theme(top: hsl(270, 0.65, 0.42), bottom: hsl(290, 0.50, 0.68), symbol: "waveform")
        } else if n.contains("80年代") || n.contains("80s") || n.contains("'80") {
            theme = Theme(top: hsl(195, 0.70, 0.40), bottom: hsl(215, 0.55, 0.68), symbol: "headphones")
        } else if n.contains("70年代") || n.contains("70s") || n.contains("'70") {
            theme = Theme(top: hsl(30, 0.75, 0.42), bottom: hsl(45, 0.60, 0.68), symbol: "music.note.list")
        } else if n.contains("お気に入り") || n.contains("favorite") || n.contains("liked") {
            theme = Theme(top: hsl(340, 0.72, 0.45), bottom: hsl(355, 0.60, 0.72), symbol: "heart.fill")
        } else if n.contains("ダウンロード") || n.contains("download") {
            theme = Theme(top: hsl(148, 0.68, 0.38), bottom: hsl(162, 0.52, 0.62), symbol: "arrow.down.circle.fill")
        } else {
            // 名前のハッシュ値から一意の色を決定
            let h = CGFloat(abs(name.hashValue) % 360)
            theme = Theme(top: hsl(h, 0.65, 0.42), bottom: hsl(fmod(h + 40, 360), 0.50, 0.68), symbol: "music.note.list")
        }

        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let colors = [theme.top.cgColor, theme.bottom.cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])

            let ptSize = size.width * 0.40
            let symConf = UIImage.SymbolConfiguration(pointSize: ptSize, weight: .medium)
            if let icon = UIImage(systemName: theme.symbol, withConfiguration: symConf)?
                .withTintColor(UIColor.white.withAlphaComponent(0.88), renderingMode: .alwaysOriginal) {
                let ix = (size.width - icon.size.width) / 2
                let iy = (size.height - icon.size.height) / 2
                icon.draw(at: CGPoint(x: ix, y: iy))
            }
        }
    }

}
