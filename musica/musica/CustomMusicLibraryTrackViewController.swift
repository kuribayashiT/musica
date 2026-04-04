//
//  CustomMusicLibraryTrackViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2017/05/03.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import MediaPlayer
import GoogleMobileAds

class CustomMusicLibraryTrackViewController: UIViewController , UITableViewDataSource, UITableViewDelegate ,MPMediaPickerControllerDelegate {
    
    @IBOutlet weak var OSTracktableview: UITableView!
    // アルバム一覧から値を受け取るための変数
    var listModeSegment = 0
    var albumSelectIndex = 0
    var osAlbumDataList : [AlbumData] = []
    var osLibraryDataList : [AlbumData] = []
    var osTrackDataList : [AlbumData] = []
    @objc dynamic var nowPlayTrackNum = 0
    @IBOutlet weak var footerHeight: NSLayoutConstraint!
    var bannerViewHeight = 92
        
    override func viewDidLoad() {
        super.viewDidLoad()
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
        // navigationbarの色設定
        self.navigationController?.navigationBar.isTranslucent = false
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor =  NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]]
            self.navigationController!.navigationBar.standardAppearance = appearance
            self.navigationController!.navigationBar.scrollEdgeAppearance = self.navigationController!.navigationBar.standardAppearance
            self.navigationController!.navigationBar.tintColor =  NAVIGATION_BTN_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
        } else {
            self.navigationController?.navigationBar.barTintColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
            self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]]
            self.navigationController!.navigationBar.tintColor =  NAVIGATION_BTN_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
        }
        bannerViewHeight = 92
        if ADApearFlg() {
            if AD_DISPLAY_MUSIC_REGISTER_TRACK_BANNER {
                // AdMobバナー広告の読み込み
                bannerViewHeight = bannerViewHeight + Int(selectBannerView.frame.height)
            }else{
                selectBannerView.isHidden = true
            }
        }else{
            selectBannerView.isHidden = true
        }
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
        OSTracktableview.translatesAutoresizingMaskIntoConstraints = false
        footerHeight.constant = -CGFloat(bannerViewHeight)
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
        if trackData.url == nil {
            cell.playBtn.tintColor = UIColor.gray
            cell.hideView.isHidden = false
            cell.TrackTitleLabel.textColor = UIColor.darkGray
            cell.TrackSubtitleLabel.textColor = UIColor.lightGray
        }else{
            cell.playBtn.tintColor = UIColor.blue
            cell.hideView.isHidden = true
            cell.TrackTitleLabel.textColor = darkModeLabelColor()
            cell.TrackSubtitleLabel.textColor = UIColor.lightGray
        }
        cell.playBtn.tag = indexPath.row
        // selectedCells[key] からチェック状態を取得
        let key = "\(String(describing: osTrackDataList[albumSelectIndex].trackData[indexPath.row].url))"

        // チェックマークを切り替える
        if let selected = selectedTracks[key]{
            cell.accessoryType=UITableViewCell.AccessoryType.checkmark
            selectedTracks[key]=selected
        }else{
            cell.accessoryType=UITableViewCell.AccessoryType.none
            selectedTracks.removeValue(forKey: key)
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

        if osTrackDataList[albumSelectIndex].trackData[indexPath.row].isCloudItem {
            // アラートを作成
            let alert = UIAlertController(
                title: DIALOGUE_TITLE_MUSIC_DATA_IN_CLOUD,
                message: DIALOGUE_MESSAGE_MUSIC_IN_CLOUD,
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: localText(key:"musictrack_howto_download"), style: .default, handler: { action in
                let nextView = self.storyboard?.instantiateViewController(withIdentifier: "howToDownloadView")
                self.present(nextView!, animated: true, completion: nil)
            }))
            // アラートにボタンをつける
            alert.addAction(UIAlertAction(title: MESSAGE_OK, style: .default))
            // アラート表示
            getForegroundViewController().present(alert, animated: true, completion: nil)
            return
        }
        if osTrackDataList[albumSelectIndex].trackData[indexPath.row].url == nil {
            // アラートを作成
            let alert = UIAlertController(
                title: DIALOGUE_TITLE_MUSIC_DATA_DRM,
                message: DIALOGUE_MESSAGE_MUSIC_DRM,
                preferredStyle: .alert)
            // アラートにボタンをつける
            alert.addAction(UIAlertAction(title: MESSAGE_OK, style: .default))
            alert.addAction(UIAlertAction(title: localText(key:"musictrack_howto_drm"), style: .default, handler: { action in
                site = DRM
                self.performSegue(withIdentifier: "DRM",sender: "")
            }))
            // アラート表示
            getForegroundViewController().present(alert, animated: true, completion: nil)
            return
        }
        let key = "\(String(describing: osTrackDataList[albumSelectIndex].trackData[indexPath.row].url))"
        
        // チェックマークを切り替える
        if selectedTracks[key] == true {
            cell.accessoryType=UITableViewCell.AccessoryType.none
            osTrackDataList[albumSelectIndex].trackData[indexPath.row].checkedFlg=false
            selectedTracks.removeValue(forKey: key)
        }else{
            cell.accessoryType=UITableViewCell.AccessoryType.checkmark
            osTrackDataList[albumSelectIndex].trackData[indexPath.row].checkedFlg=true
            selectedTracks[key]=true;
        }
        
        selectMusicLabel.text = String(selectedTracks.count) + localText(key:"musiclibrary_selected_track_num")
        if selectedTracks.count == 0 {
            selectMusicLabel.textColor = UIColor.lightGray
            selectMusicButton.backgroundColor = UIColor.lightGray
        }else{
            selectMusicLabel.textColor = UIColor(red: 0, green: 122 / 255, blue: 1,alpha: 1)
            selectMusicButton.backgroundColor = UIColor.systemBlue
        }
        selectMusicLabel.sizeToFit()
        // Cellの 更新処理
        OSTracktableview.reloadData()
    }

    /*******************************************************************
     ボタンタップ時の処理
     *******************************************************************/
    @IBAction func allCheckReleaseBtnTapped(_ sender: Any) {
        for var track in osTrackDataList[albumSelectIndex].trackData {
            if track.url == nil {
                continue
            }
            let key = "\(String(describing: track.url))"
            
            // selectedTracks を全て false へ
            selectedTracks.removeValue(forKey: key)
            track.checkedFlg=false
        }
        // Cellの 更新処理
        selectMusicLabel.text = String(selectedTracks.count) + localText(key:"musiclibrary_selected_track_num")
        if selectedTracks.count == 0 {
            selectMusicLabel.textColor = UIColor.lightGray
            selectMusicButton.backgroundColor = UIColor.lightGray
        }else{
            selectMusicLabel.textColor = UIColor(red: 0, green: 122 / 255, blue: 1,alpha: 1)
            selectMusicButton.backgroundColor = UIColor.systemBlue
        }
        selectMusicLabel.sizeToFit()
        OSTracktableview.reloadData()
    }
    /* 「全て選択する」ボタンを押された際の挙動　*/
    @IBAction func allCheckBtn(_ sender: Any) {
        for var track in osTrackDataList[albumSelectIndex].trackData {
            if track.url == nil {
                continue
            }
            let key = "\(String(describing: track.url))"

            // selectedTracks を全て true へ
            selectedTracks[key]=true
            track.checkedFlg=true
        }
        selectMusicLabel.text = String(selectedTracks.count) + localText(key:"musiclibrary_selected_track_num")
        if selectedTracks.count == 0 {
            selectMusicLabel.textColor = UIColor.lightGray
            selectMusicButton.backgroundColor = UIColor.lightGray
        }else{
            selectMusicLabel.textColor = UIColor(red: 0, green: 122 / 255, blue: 1,alpha: 1)
            selectMusicButton.backgroundColor = UIColor.systemBlue
        }
        selectMusicLabel.sizeToFit()
        // Cellの 更新処理
        OSTracktableview.reloadData()
    }
    // 引っ越し
    @IBAction func playBtnTapped(_ sender: Any) {
        // ステータスバーの高さ
        // 端末内に、再生データがあるかチェック。
        if osTrackDataList[albumSelectIndex].trackData[(sender as AnyObject).tag].existFlg == false{
            showAlertMsgOneOkBtn(title: ERR_DIALOGUE_TITLE_MUSIC_DATA_NONE,
                                 messege:ERR_DIALOGUE_MESSAGE_MUSIC_DATA_NONE)
        }else{
            // 押されたボタンが再生中の曲のボタンだったら、曲を止める
            if playingTestTracks[(sender as AnyObject).tag] != nil{
                audioTestPlayer.stop()
                playingTestTracks = [:]
            }else{
                playingTestTracks = [:]
                
                if (audioTestPlayer != nil && audioTestPlayer.isPlaying){
                    // auido が再生中であれば曲を止める。
                    audioTestPlayer.stop()
                }
                // auido が再生中でなければ、再生するプレイヤーを作成する
                let audioUrl = osTrackDataList[albumSelectIndex].trackData[(sender as AnyObject).tag].url
                if audioUrl == nil {
                    return
                }
                var audioError:NSError?
                do {
                    audioTestPlayer = try AVAudioPlayer(contentsOf: audioUrl!)
                    audioTestPlayer.delegate = self as? AVAudioPlayerDelegate
                    audioTestPlayer.prepareToPlay()
                    playingTestTracks[(sender as AnyObject).tag]=true
                    
                } catch let error as NSError {
                    playingTestTracks = [:]
                    audioError = error
                    audioTestPlayer = nil
                }
                // エラーチェック
                if let error = audioError {
                    print("Error \(error.localizedDescription)")
                }else{
                    audioTestPlayer.play()
                    playingTestTracks[(sender as AnyObject).tag]=false
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
