//
//  CustomMusicLibraryTrackViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2017/05/03.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import MediaPlayer

class CustomMusicLibraryTrackViewController: UIViewController , UITableViewDataSource, UITableViewDelegate ,MPMediaPickerControllerDelegate {

    @IBOutlet weak var OSTracktableview: UITableView!
    var listModeSegment = 0
    var albumSelectIndex = 0
    var osAlbumDataList : [AlbumData] = []
    var osLibraryDataList : [AlbumData] = []
    var osTrackDataList : [AlbumData] = []
    @objc dynamic var nowPlayTrackNum = 0
    @IBOutlet weak var footerHeight: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "曲を選択"
        OSTracktableview.tableHeaderView = makeLibraryGuideCard(
            step: 2, total: 3,
            icon: "checkmark.circle",
            title: "練習したい曲にチェックを入れる",
            body: "複数選択できます。「全て選択」「全て解除」ボタンも使えます。前の画面に戻って別のアルバムやプレイリストの曲をまとめて追加することもできます。選曲後は下の「次へ」ボタンをタップしてください。"
        )
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    /*******************************************************************
     画面描画時の処理
     *******************************************************************/
    override func viewWillAppear(_ animated: Bool) {
        if #available(iOS 13.0, *), IOS13_RESIST_FLG {
            IOS13_RESIST_FLG = false
            self.navigationController?.popToRootViewController(animated: true)
            return
        }
        super.viewWillAppear(animated)
        selectMusicView.isHidden = false
        selectBannerView.isHidden = true
        // navigationbarの色設定
        self.navigationController?.navigationBar.isTranslucent = false
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]]
            self.navigationController!.navigationBar.standardAppearance = appearance
            self.navigationController!.navigationBar.scrollEdgeAppearance = self.navigationController!.navigationBar.standardAppearance
            self.navigationController!.navigationBar.tintColor = AppColor.accent
        } else {
            self.navigationController?.navigationBar.barTintColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
            self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]]
            self.navigationController!.navigationBar.tintColor = AppColor.accent
        }
        updateFooterAppearance()
        OSTracktableview.translatesAutoresizingMaskIntoConstraints = false
        footerHeight.constant = -92
        OSTracktableview.reloadData()
    }
    /* セクションの個数 */
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    /* セクション内の行数 */
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Listの値の個数
        return osTrackDataList[albumSelectIndex].trackData.count
    }
    // tableフッダーの高さをかえします。
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    // tableフッターにViewをセットしてかえします。
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    @objc func toRegistMusicLibrary(){
        if selectedTracks.count > 0 {
            performSegue(withIdentifier: "toMusicLibraryRegist", sender: "")
        }else{
            showToastMsg(messege:LISTMODE_LIVRARY_NOSELECTED,time:2.0, tab: COLOR_THEMA.HOME.rawValue)
        }
    }
    /* セルを作る */
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // テーブルのセルを参照する
        let cell = tableView.dequeueReusableCell(withIdentifier: "TrackData", for: indexPath) as! CustomTrackListTableViewCell
        
        // テーブルにTrackListのデータを表示する
        let trackData = osTrackDataList[albumSelectIndex].trackData[(indexPath as NSIndexPath).row]
        
        // セルに値を設定
        cell.setCell(titleText: trackData.title,descriptionText: trackData.artist)
        
        //cell内のBtnタップイベント取得のため、tagを設定
        if playingTestTracks[indexPath.row] != nil{
            cell.playBtn.setImage(stopBtnImage.withRenderingMode(.alwaysTemplate), for: .normal)
        }else{
            cell.playBtn.setImage(playBtnImage.withRenderingMode(.alwaysTemplate), for: .normal)
        }
        let canPlay = trackData.url != nil || trackData.hasProtectedAsset
        if canPlay {
            cell.playBtn.tintColor = trackData.hasProtectedAsset ? UIColor.systemPink : AppColor.accent
            cell.hideView.isHidden = true
            cell.TrackTitleLabel.textColor = darkModeLabelColor()
            cell.TrackSubtitleLabel.textColor = AppColor.textSecondary
        } else {
            cell.playBtn.tintColor = UIColor.gray
            cell.hideView.isHidden = false
            cell.TrackTitleLabel.textColor = UIColor.darkGray
            cell.TrackSubtitleLabel.textColor = AppColor.textSecondary
        }
        cell.playBtn.tag = indexPath.row
        // selectionKey でチェック状態を取得
        let key = trackData.selectionKey
        if let selected = selectedTracks[key] {
            cell.accessoryType = selected ? .checkmark : .none
        } else {
            cell.accessoryType = .none
        }
        // TODO 超絶行けてない
        cell.Album = osTrackDataList[albumSelectIndex]
        
        return cell
    }

    /* UITableViewDelegateデリゲートメソッド */
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath as IndexPath, animated: true)
        // 現在の状態を確認してから、チェックマークの有無を確認
        let cell=tableView.cellForRow(at: indexPath) as! CustomTrackListTableViewCell

        let track = osTrackDataList[albumSelectIndex].trackData[indexPath.row]

        // Apple Music DRM トラックは選択可能
        if !track.hasProtectedAsset {
            if track.isCloudItem {
                let alert = UIAlertController(title: DIALOGUE_TITLE_MUSIC_DATA_IN_CLOUD, message: DIALOGUE_MESSAGE_MUSIC_IN_CLOUD, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: localText(key:"musictrack_howto_download"), style: .default) { _ in
                    let nextView = self.storyboard?.instantiateViewController(withIdentifier: "howToDownloadView")
                    self.present(nextView!, animated: true, completion: nil)
                })
                alert.addAction(UIAlertAction(title: MESSAGE_OK, style: .default))
                getForegroundViewController().present(alert, animated: true, completion: nil)
                return
            }
            if track.url == nil {
                let alert = UIAlertController(title: DIALOGUE_TITLE_MUSIC_DATA_DRM, message: DIALOGUE_MESSAGE_MUSIC_DRM, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: MESSAGE_OK, style: .default))
                alert.addAction(UIAlertAction(title: localText(key:"musictrack_howto_drm"), style: .default) { _ in
                    site = DRM
                    self.performSegue(withIdentifier: "DRM", sender: "")
                })
                getForegroundViewController().present(alert, animated: true, completion: nil)
                return
            }
        }

        let key = track.selectionKey
        if selectedTracks[key] == true {
            cell.accessoryType = .none
            osTrackDataList[albumSelectIndex].trackData[indexPath.row].checkedFlg = false
            selectedTracks.removeValue(forKey: key)
        } else {
            cell.accessoryType = .checkmark
            osTrackDataList[albumSelectIndex].trackData[indexPath.row].checkedFlg = true
            selectedTracks[key] = true
        }
        
        updateFooterAppearance()
        selectMusicLabel.sizeToFit()
        // Cellの 更新処理
        OSTracktableview.reloadData()
    }

    /*******************************************************************
     ボタンタップ時の処理
     *******************************************************************/
    @IBAction func allCheckReleaseBtnTapped(_ sender: Any) {
        for var track in osTrackDataList[albumSelectIndex].trackData {
            guard track.url != nil || track.hasProtectedAsset else { continue }
            selectedTracks.removeValue(forKey: track.selectionKey)
            track.checkedFlg = false
        }
        // Cellの 更新処理
        updateFooterAppearance()
        selectMusicLabel.sizeToFit()
        OSTracktableview.reloadData()
    }
    /* 「全て選択する」ボタンを押された際の挙動　*/
    @IBAction func allCheckBtn(_ sender: Any) {
        for var track in osTrackDataList[albumSelectIndex].trackData {
            guard track.url != nil || track.hasProtectedAsset else { continue }
            selectedTracks[track.selectionKey] = true
            track.checkedFlg = true
        }
        updateFooterAppearance()
        selectMusicLabel.sizeToFit()
        // Cellの 更新処理
        OSTracktableview.reloadData()
    }
    private func updateFooterAppearance() {
        let hasSelection = selectedTracks.count > 0
        selectMusicLabel.text = String(selectedTracks.count) + localText(key: "musiclibrary_selected_track_num")
        selectMusicLabel.textColor = hasSelection ? AppColor.accent : AppColor.textDisabled
        selectMusicButton.backgroundColor = hasSelection ? AppColor.accent : AppColor.inactive
    }

    @IBAction func playBtnTapped(_ sender: Any) {
        let tag = (sender as AnyObject).tag
        let trackData = osTrackDataList[albumSelectIndex].trackData[tag]

        guard trackData.existFlg else {
            showAlertMsgOneOkBtn(title: ERR_DIALOGUE_TITLE_MUSIC_DATA_NONE,
                                 messege: ERR_DIALOGUE_MESSAGE_MUSIC_DATA_NONE)
            return
        }

        if trackData.hasProtectedAsset {
            // Apple Music: MPMusicPlayerController で再生
            let player = MPMusicPlayerController.applicationQueuePlayer
            if playingTestTracks[tag] != nil {
                player.stop()
                playingTestTracks = [:]
            } else {
                playingTestTracks = [:]
                if audioTestPlayer != nil && audioTestPlayer.isPlaying { audioTestPlayer.stop() }
                player.stop()
                let query = MPMediaQuery()
                query.addFilterPredicate(MPMediaPropertyPredicate(
                    value: trackData.persistentID,
                    forProperty: MPMediaItemPropertyPersistentID))
                player.setQueue(with: query)
                player.play()
                playingTestTracks[tag] = true
            }
        } else {
            // 端末内ローカル曲: AVAudioPlayer で再生
            guard let audioUrl = trackData.url else { return }
            if playingTestTracks[tag] != nil {
                audioTestPlayer.stop()
                playingTestTracks = [:]
            } else {
                playingTestTracks = [:]
                if audioTestPlayer != nil && audioTestPlayer.isPlaying { audioTestPlayer.stop() }
                MPMusicPlayerController.applicationQueuePlayer.stop()
                do {
                    audioTestPlayer = try AVAudioPlayer(contentsOf: audioUrl)
                    audioTestPlayer.delegate = self as? AVAudioPlayerDelegate
                    audioTestPlayer.prepareToPlay()
                    audioTestPlayer.play()
                    playingTestTracks[tag] = false
                } catch {
                    dlog("Error \(error.localizedDescription)")
                }
            }
        }
        OSTracktableview.reloadData()
    }
    /*
     　画面遷移時の処理
     */
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if (audioTestPlayer != nil && audioTestPlayer.isPlaying ){
            // auido が再生中であれば曲を止める。
            audioTestPlayer.stop()
            OSTracktableview.reloadData()
        }
        if segue.identifier == "toMusicLibraryRegist" {
            // CustamMusicLibraryRegisterViewControllerをインスタンス化
            let secondVc = segue.destination as! CustamMusicLibraryRegisterViewController
            secondVc.listModeSegment = listModeSegment
            // 値を渡す
            //secondVc.osAlbumDataList = osTrackDataList
            secondVc.osAlbumDataList = osAlbumDataList
            secondVc.osLibraryDataList = osLibraryDataList
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        selectMusicView.isHidden = true
    }

    // MARK: - Navigation
    // ナビゲーションバーで戻る
    override func didMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            if (audioTestPlayer != nil && audioTestPlayer.isPlaying ){
                // auido が再生中であれば曲を止める。
                audioTestPlayer.stop()
                playingTestTracks = [:]
            }
        }
    }
}
