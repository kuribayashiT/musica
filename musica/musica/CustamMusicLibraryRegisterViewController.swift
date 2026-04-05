//
//  CustamMusicLibraryRegisterViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2017/05/06.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import MediaPlayer
import AVFoundation
import CoreData
import GoogleMobileAds

class CustamMusicLibraryRegisterViewController: UIViewController , UITableViewDataSource, UITableViewDelegate ,MPMediaPickerControllerDelegate, FullScreenContentDelegate {
    
    @IBOutlet weak var registBtnBtmMargin: NSLayoutConstraint!
    @IBOutlet weak var waitView: UIVisualEffectView!
    @IBOutlet weak var keyBoardClouseBtn: UIButton!
    @IBOutlet weak var selectedTrackDataTableView: UITableView!
    @IBOutlet weak var registMusicLibrayBtn: UIButton!
    var interstitial: InterstitialAd?
    var selectedAlbumDataList: [AlbumData] = []
    var selectedTrackDataList: [TrackData] = []
    var chechNumCount : Int = 0
    //var OSAlbumList: [AlbumData] = []
    var osAlbumDataList : [AlbumData] = []
    var osLibraryDataList : [AlbumData] = []
    var listModeSegment = 0
    var selectedIconNum = 0
    var selectedColorNum = 0
    var keyBoardMaxHeight:CGFloat = 0
    var nowCV = UIViewController()
    @IBOutlet weak var progress: UIProgressView!
    
    @IBOutlet weak var libraryResistNameTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        libraryResistNameTextField.text = CUSTOM_LYBRARY_NAME
        waitView.isHidden = true
        // キーボードの設定
        keyBoardClouseBtn.isHidden = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.keyboardWillChangeFrame(notification:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.keyboardWillHide(notification:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        nowCV = self
        // キーボードの「閉じる」ボタン作成
        let kbToolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 40))
        kbToolBar.barStyle = UIBarStyle.default  // スタイルを設定
        kbToolBar.sizeToFit()  // 画面幅に合わせてサイズを変更
        // スペーサー
        let spacer = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: self, action: nil)
        // 閉じるボタン
        let commitButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.done, target: self, action: #selector(CustamMusicLibraryRegisterViewController.editCloseBtnTapped))
        kbToolBar.items = [spacer, commitButton]
        libraryResistNameTextField.inputAccessoryView = kbToolBar
        
        // 「決定」ボタンのレイアウト
        registMusicLibrayBtn.layer.cornerRadius = ICON_CORNER_RADIUS_SETTINMGS
        
        // Do any additional setup after loading the view.
        selectedTrackDataTableView.isEditing = true
        
        var checkKey:[String] = []
        
        // チェックされたアルバムのトラックを全てリスト化
        for album in osAlbumDataList{
            for track in album.trackData{
                let key = "\(String(describing: track.url))"
                if selectedTracks[key] != nil {
                    if selectedTrackDataList.count == 0{
                        selectedTrackDataList.append(track)
                        selectedTrackDataList[selectedTrackDataList.count - 1].albumName = album.title!
                        chechNumCount = chechNumCount + 1
                        checkKey.append(key)
                    }
                    if !checkKey.contains(key){
                        selectedTrackDataList.append(track)
                        selectedTrackDataList[selectedTrackDataList.count - 1].albumName = album.title!
                        chechNumCount = chechNumCount + 1
                        checkKey.append(key)
                    }
                }
            }
        }
        
//        for _key in selectedTracks {
//            for album in osAlbumDataList{
//                for track in album.trackData{
//                    let key = "\(String(describing: track.url))"
//                    if _key.key == key {
//                        if selectedTrackDataList.count == 0{
//                            selectedTrackDataList.append(track)
//                            selectedTrackDataList[selectedTrackDataList.count - 1].albumName = album.title!
//                            chechNumCount = chechNumCount + 1
//                            checkKey.append(key)
//                        }
//                        if !checkKey.contains(key){
//                            selectedTrackDataList.append(track)
//                            selectedTrackDataList[selectedTrackDataList.count - 1].albumName = album.title!
//                            chechNumCount = chechNumCount + 1
//                            checkKey.append(key)
//                        }
//                    }
//
//                }
//            }
//        }
//
        // チェックされたライブラリのトラックを全てリスト化
        for library in osLibraryDataList{
            for track in library.trackData{
                let key = "\(String(describing: track.url))"
                if selectedTracks[key] != nil {
                    if selectedTrackDataList.count == 0{
                        selectedTrackDataList.append(track)
                        selectedTrackDataList[selectedTrackDataList.count - 1].albumName = library.title!
                        chechNumCount = chechNumCount + 1
                        checkKey.append(key)
                    }
                    if !checkKey.contains(key){
                        selectedTrackDataList.append(track)
                        selectedTrackDataList[selectedTrackDataList.count - 1].albumName = library.title!
                        chechNumCount = chechNumCount + 1
                        checkKey.append(key)
                    }
                }
            }
        }
    }
    override func viewDidAppear(_ animated: Bool) {
       super.viewDidAppear(animated)
        if #available(iOS 13.0, *) {
            presentingViewController?.endAppearanceTransition()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
       super.viewWillDisappear(animated)
       if #available(iOS 13.0, *) {
           presentingViewController?.beginAppearanceTransition(true, animated: animated)
           presentingViewController?.endAppearanceTransition()
        }
    }
    /*******************************************************************
     画面描画時の処理
     *******************************************************************/
    override func viewWillAppear(_ animated: Bool) {
        if #available(iOS 13.0, *) {
            presentingViewController?.beginAppearanceTransition(false, animated: animated)
        }
        progress.progress = 0
        super.viewWillAppear(animated)
        libraryResistNameTextField.placeholder = localText(key: "library_resist_name_placeholder")
        selectMusicView.isHidden = true
        // navigationbarの色設定
        self.navigationController?.navigationBar.isTranslucent = false
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]]
            self.navigationController?.navigationBar.standardAppearance = appearance
            self.navigationController?.navigationBar.scrollEdgeAppearance = self.navigationController!.navigationBar.standardAppearance
            self.navigationController?.navigationBar.tintColor = NAVIGATION_BTN_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
        } else {
            self.navigationController?.navigationBar.barTintColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
            self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]]
            self.navigationController?.navigationBar.tintColor = NAVIGATION_BTN_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
        }
        
//        // Ingcatorの設定
//        waitIngcator.stopAnimating()
//        waitIngcator.color = INGCATOR_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
//        waitIngcator.type = INGCATOR_TYPE[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
//        waitIngcator.startAnimating()
        // 広告の準備
        loadInterstitial()
        if #available(iOS 13.0, *) {
            self.isModalInPresentation = false
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /*******************************************************************
     tableView 処理
     *******************************************************************/
    // セクションの個数
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    // セクション内の行数
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // 選択されたトラックの個数
        return chechNumCount
    }
    
    // セルを作る
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // テーブルのセルを参照する
        let cell = selectedTrackDataTableView.dequeueReusableCell(withIdentifier: "RegistMusicData", for: indexPath) as! CustamMusicLibraryRegisterTableViewCell
        
        // テーブルに選択されたTrackのデータを表示する
        cell.trackTitleLabel.text = selectedTrackDataList[(indexPath as NSIndexPath).row].title
        cell.artistLabel.text = selectedTrackDataList[(indexPath as NSIndexPath).row].artist
        cell.albumTitleLabel.text = selectedTrackDataList[(indexPath as NSIndexPath).row].albumName
        return cell
    }
    
    //テーブルビュー編集時に呼ばれるメソッド
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        //削除の場合、配列からデータを削除する。
        if( editingStyle == UITableViewCell.EditingStyle.delete) {
            
            selectedTrackDataList[indexPath.row].checkedFlg = false
            let key = "\(String(describing: selectedTrackDataList[indexPath.row].url))"
            
            selectedTracks.removeValue(forKey: key)
            selectedTrackDataList.remove(at: indexPath.row)
            chechNumCount = chechNumCount - 1
        }
        
        //テーブルの再読み込み
        selectedTrackDataTableView.reloadData()
    }
    
    //並び替え時に呼ばれるメソッド
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath){
        
        //移動されたデータを取得する。
        let moveData = selectedTrackDataList[sourceIndexPath.row]
        
        //元の位置のデータを配列から削除する。
        selectedTrackDataList.remove(at: sourceIndexPath.row)
        
        //移動先の位置にデータを配列に挿入する。
        selectedTrackDataList.insert(moveData , at:destinationIndexPath.row)
    }

    /*******************************************************************
     Coredata 保存処理
     *******************************************************************/
    // MusicLibraryを登録する
    @IBAction func registMusicLibrayBtnTapped(_ sender: Any) {
        let musicLibraryName = libraryResistNameTextField.text
        if musicLibraryName == "" {
            showAlertMsgOneOkBtn(title: MUSICLIBRALY_REGIST_ERR_NONNAME_DIALOG_TITLE,
                                 messege:MUSICLIBRALY_REGIST_ERR_NONNAME_DIALOG_MESSAGE)
            return
        }
        if selectedTrackDataList.count == 0 {
            showAlertMsgOneOkBtn(title: MUSICLIBRALY_REGIST_ERR_NONSELECT_DIALOG_TITLE,
                                 messege:MUSICLIBRALY_REGIST_ERR_NONSELECT_DIALOG_MESSAGE)
            return
        }
        
        if #available(iOS 13.0, *) {
            self.isModalInPresentation = true
        }
        let duration: TimeInterval? = 0.2
        UIView.animate(
            withDuration: duration!,
            animations:{
                self.waitView.isHidden = false
                self.libraryResistNameTextField.resignFirstResponder()
                self.keyboardWillBeHidden()
                //NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
                self.navigationController?.navigationBar.isUserInteractionEnabled = false
                self.navigationController?.interactivePopGestureRecognizer!.isEnabled = false
                self.navigationController?.navigationBar.tintColor = UIColor.lightGray
                self.waitView.alpha = 1.0

            }, completion:{ finished in
                //if (finished) {
                    if CUSTOM_LYBRARY_FROM_MUSICLIST {
                        if CUSTOM_LYBRARY_NAME != musicLibraryName{
                            if checkMusicLibraryNameExistence(checkName:musicLibraryName!) {
                                self.navigationController?.navigationBar.isUserInteractionEnabled = true
                                self.navigationController?.navigationBar.tintColor = NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
                                self.waitView.isHidden = true
                                showAlertMsgOneOkBtn(title: MUSICLIBRALY_REGIST_ERR_SAMENAME_DIALOG_TITLE,messege: MUSICLIBRALY_REGIST_ERR_SAMENAME_DIALOG_MESSAGE)

                                if #available(iOS 13.0, *) {
                                    self.isModalInPresentation = false
                                }
                                return
                            }
                        }
                        // 登録する
                        let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
                        TAB_MOVE_FLG = false
                        updateMusicLibrary(appdelegate:appDelegate,oldLibraryName:CUSTOM_LYBRARY_NAME,newLibraryName:musicLibraryName!,trackList:self.selectedTrackDataList ,progress:self.progress,vc:self, completion: {(rs: Bool)  -> Void in
                            if rs {
                                DispatchQueue.main.async{
                                    do {
                                        try appDelegate.managedObjectContext.save()
                                        if CUSTOM_LYBRARY_NAME != "" {
                                            CUSTOM_LYBRARY_FLG = true
                                            CUSTOM_LYBRARY_NAME = ""
                                        }
                                        CUSTOM_LYBRARY_FROM_MUSICLIST = false
                                        self.waitView.isHidden = true
                                        self.coredataSuccessDialog()
                                    }catch {
                                        self.coredataErrDialog()
                                    }
                                }
                            }else{
                                DispatchQueue.main.async{
                                    self.coredataErrDialog()
                                }
                            }
                        })
                    }else{
                        if checkMusicLibraryNameExistence(checkName:musicLibraryName!) {
                            self.navigationController?.navigationBar.isUserInteractionEnabled = true
                            self.navigationController?.navigationBar.tintColor = NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
                            self.waitView.isHidden = true
                            showAlertMsgOneOkBtn(title: MUSICLIBRALY_REGIST_ERR_SAMENAME_DIALOG_TITLE,messege: MUSICLIBRALY_REGIST_ERR_SAMENAME_DIALOG_MESSAGE)
                            if #available(iOS 13.0, *) {
                                self.isModalInPresentation = false
                            }
                            return
                        }
                        TAB_MOVE_FLG = false
                        // 登録する
                        let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
                        registNewMusicLibrary(appdelegate:appDelegate,libraryName:musicLibraryName!,trackList:self.selectedTrackDataList ,progress:self.progress,vc:self, completion: {(rs: Bool)  -> Void in
                            if rs {
                                DispatchQueue.main.async{
                                    do {
                                        try appDelegate.managedObjectContext.save()
                                        CUSTOM_LYBRARY_NAME = ""
                                        self.waitView.isHidden = true
                                        self.coredataSuccessDialog()
                                    }catch {
                                        DispatchQueue.main.async{
                                            self.coredataErrDialog()
                                        }
                                    }
                                }
                            }else{
                                DispatchQueue.main.async{
                                    self.coredataErrDialog()
                                }
                            }
                            
                        })
                    }
               // }
        });
    }

    /*******************************************************************
     Coredata 完了時の処理
     *******************************************************************/
    // 成功時
    func coredataSuccessDialog(){
        TAB_MOVE_FLG = true
        RESIST_LIBRARY_COMPLETE_FLG = true
        setLibraryNameData(name:libraryResistNameTextField.text!,truck_num:selectedTrackDataList.count)
        self.navigationController?.navigationBar.isUserInteractionEnabled = true
        self.navigationController?.navigationBar.tintColor = NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
        // ここまできたら成功
        // アラートを作成
        let alert = UIAlertController(
            title: MUSICLIBRALY_REGIST_COMP_DIALOG_TITLE,
            message: MUSICLIBRALY_REGIST_COMP_DIALOG_MESSAGE,
            preferredStyle: .alert)
        
        // アラートにボタンをつける
        let okAction = UIAlertAction(title: MESSAGE_OK, style: UIAlertAction.Style.default){ (action: UIAlertAction) in
            // 選択中の曲を初期化
            selectedTracks = [:]

            if ADApearFlg() && self.interstitial != nil {
                self.interstitial?.present(from: self)
            }else{
                // TOP画面へ遷移
                if #available(iOS 13.0, *) {
                    IOS13_RESIST_FLG = true
                    self.isModalInPresentation = false
                    self.dismiss(animated: true, completion: nil)
                }else{
                    self.navigationController?.popToRootViewController(animated: true)
                }
                
            }
        }
        alert.addAction(okAction)
        // アラート表示
        nowCV.present(alert, animated: true, completion: nil)
        self.navigationController?.interactivePopGestureRecognizer!.isEnabled = true

    }
    // 失敗時
    func coredataErrDialog(){
        TAB_MOVE_FLG = true
        self.navigationController?.navigationBar.isUserInteractionEnabled = true
        self.navigationController?.navigationBar.tintColor = NAVIGATION_TEXT_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.HOME.rawValue]
        self.waitView.isHidden = true
        showAlertMsgOneOkBtn(title: MUSICLIBRALY_REGIST_ERR_COREDATA_DIALOG_TITLE,
                             messege:MUSICLIBRALY_REGIST_ERR_COREDATA_DIALOG_MASSAGE)
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.keyboardWillHide(notification:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        if #available(iOS 13.0, *) {
            self.isModalInPresentation = false
        }
    }
    /*******************************************************************
     広告取得処理
     *******************************************************************/
    func loadInterstitial() {
        InterstitialAd.load(with: ADMOB_INTERSTITIAL_CUSTUM_LIBRARY, request: Request()) { [weak self] ad, error in
            if let error = error { print("Interstitial failed to load: \(error)"); return }
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
        }
    }
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        loadInterstitial()
        // TOP画面へ遷移
        if #available(iOS 13.0, *) {
            IOS13_RESIST_FLG = true
            self.dismiss(animated: true, completion: nil)
        }else{
            self.navigationController?.popToRootViewController(animated: true)
        }
    }
    func adWillLeaveApplication(_ ad: FullScreenPresentingAd) {
        self.dismiss(animated: true, completion: nil)
        // TOP画面へ遷移
        if #available(iOS 13.0, *) {
            IOS13_RESIST_FLG = true
            self.dismiss(animated: false, completion: nil)
        }else{
            self.navigationController?.popToRootViewController(animated: true)
        }
    }
    /*******************************************************************
     text編集周りの処理
     *******************************************************************/
    //キーボードが閉じられるときの呼び出しメソッド
    func keyboardWillBeHidden(/*notification:NSNotification*/){
        keyBoardClouseBtn.isHidden = true
    }
    
    //キーボードが開くときの呼び出しメソッド
    @objc func keyboardWillChangeFrame(notification:NSNotification) {
        // キーボード閉じるボタンを表示
        keyBoardClouseBtn.isHidden = false
        let rect = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        let duration : TimeInterval = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey]! as! TimeInterval
        if keyBoardMaxHeight < (rect?.size.height)! {
            keyBoardMaxHeight = (rect?.size.height)!
        }
        UIView.animate(withDuration: duration, animations: { () in
            if #available(iOS 13.0, *) {
                self.registBtnBtmMargin.constant = self.keyBoardMaxHeight //- 16
            }else{
                self.registBtnBtmMargin.constant = self.keyBoardMaxHeight //- 16 - getSafeAreaHeghtPlusSafeArea()
            }
            self.view.layoutIfNeeded()
        })
    }
    // キーボード閉じる時
    @objc func keyboardWillHide(notification: NSNotification) {
        let duration: TimeInterval? = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval
        DispatchQueue.main.async {
            // キーボード閉じるボタンを非表示表示
            self.keyBoardClouseBtn.isHidden = true
            UIView.animate(withDuration: duration!, animations: { () in
                self.registBtnBtmMargin.constant = 24
            })
        }
    }
    
    //「閉じるボタン」で呼び出されるメソッド
    @IBAction func keyBoardClouseBtnTapped(_ sender: Any) {
        //キーボードを閉じる
        libraryResistNameTextField.resignFirstResponder()
        keyboardWillBeHidden()
    }
    //「閉じるボタン」で呼び出されるメソッド
    @objc func editCloseBtnTapped() {
        //キーボードを閉じる
        libraryResistNameTextField.resignFirstResponder()
        keyboardWillBeHidden()
    }
}
