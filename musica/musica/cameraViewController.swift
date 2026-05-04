//
//  cameraViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2017/09/13.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import AVFoundation
import GoogleMobileAds
import SwiftyJSON
import Alamofire
import Firebase

class cameraViewController: UIViewController ,AVCapturePhotoCaptureDelegate ,UICollectionViewDelegateFlowLayout,UICollectionViewDelegate, UICollectionViewDataSource, APVAdManagerDelegate,FADDelegate{
    
    let cellMargin : CGFloat = 1.0
    /*
     カメラ関連
     */
    @IBOutlet weak var cameraView: UIView!
    var captureSesssion: AVCaptureSession!
    var stillImageOutput: AVCapturePhotoOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    @IBOutlet weak var cameraGritView: UICollectionView!
    @IBOutlet weak var shutterBtn: UIButton!
    @IBOutlet weak var flashSetting: UISegmentedControl!
    var timer: Timer!
    //var tesseract:G8Tesseract! = G8Tesseract(language:"eng+jpn")
    var TimP : Int = 0
    
    // 非同期処理
    var dispatchQueue = DispatchQueue(label: "Dispatch Queue", attributes: [], target: nil)
    
    @IBOutlet weak var waitViewWithAD: UIView!
    var interstitial: InterstitialAd?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        waitViewWithAD.isHidden = true
        shutterBtn.isEnabled = true
        //UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue, forKey: "orientation")
        // 広告　dW320H180の生成と表示
        setupFiveSDK()
        // 広告　Admobの生成
        InterstitialAd.load(with: "ca-app-pub-1929244717899448/1782653178", request: Request()) { [weak self] ad, error in
            if let error = error { dlog("Interstitial load error: \(error)"); return }
            self?.interstitial = ad
        }
        // 解像度の設定
        captureSesssion = AVCaptureSession()
        stillImageOutput = AVCapturePhotoOutput()
        captureSesssion.sessionPreset = AVCaptureSession.Preset.hd1920x1080
        let device = AVCaptureDevice.default(for: .video)
        do {
            let input = try AVCaptureDeviceInput(device: device!)
            // 入力
            if (captureSesssion.canAddInput(input)) {
                captureSesssion.addInput(input)
                // 出力
                if (captureSesssion.canAddOutput(stillImageOutput!)) {
                    // カメラ起動
                    captureSesssion.addOutput(stillImageOutput!)
                    captureSesssion.startRunning()
                    // アスペクト比、カメラの向き(縦)
                    previewLayer = AVCaptureVideoPreviewLayer(session: captureSesssion)
                    previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
                    previewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
                    previewLayer?.frame = cameraView.bounds
                    cameraView.layer.addSublayer(previewLayer!)
                }
            }
        }
       catch {
            dlog(error)
        }
    }
    /*******************************************************************
     画面描画時の処理
     *******************************************************************/
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = cameraView.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 動画は一旦止める
        if AVPlayerViewControllerManager.shared.controller.player != nil {
            AVPlayerViewControllerManager.shared.controller.player?.pause()
        }
        selectMusicView.isHidden = true
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    //コレクションビューのセクション数　今回は2つに分ける
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    //データの個数（DataSourceを設定した場合に必要な項目）
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 18
        
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        //コレクションビューから識別子「CalendarCell」のセルを取得する
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        cell.backgroundColor = UIColor.black
        return cell
    }
    /*
     セルのレイアウト設定
     */
    //セルサイズの指定（UICollectionViewDelegateFlowLayoutで必須）　横幅いっぱいにセルが広がるようにしたい
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let numberOfMargin:CGFloat = 2.0
        let widths:CGFloat = (collectionView.frame.size.width - cellMargin * numberOfMargin)/CGFloat(3)
        let heights:CGFloat = widths
        
        return CGSize(width:widths,height:heights)
    }
    
    //セルのアイテムのマージンを設定
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0.0 , left: 0.0 , bottom: 0.0 , right: 0.0 )  //マージン(top , left , bottom , right)
    }
    
    //セルの水平方向のマージンを設定
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return cellMargin
    }
    //セルの垂直方向のマージンを設定
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return cellMargin*2
    }
    /*******************************************************************
     カメラ周りの処理処理
     *******************************************************************/
    // カメラで撮影完了時にフォトライブラリに保存
    func photoOutput(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        
        if let photoSampleBuffer = photoSampleBuffer {
            
            // JPEG形式で画像データを取得
            let photoData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer)
            
            //let image = UIImage(data: photoData!)
            
            
            let myImage = UIImage(data: photoData!)
            let ciImage: CIImage = CIImage(image: myImage!)!
            
            //モノクロ
            let ciFilter: CIFilter = CIFilter(name: "CIColorMonochrome")!
            ciFilter.setValue(ciImage, forKey: kCIInputImageKey)
            ciFilter.setValue(CIColor(red: 0.75, green: 0.75, blue: 0.75), forKey: "inputColor")
            ciFilter.setValue(1.0, forKey: "inputIntensity")
            
            //向きとか調整
            let ciContext: CIContext = CIContext(options: nil)
            let cgimg: CGImage = ciContext.createCGImage(ciFilter.outputImage!, from: (ciFilter.outputImage?.extent)!)!
            let afterImage: UIImage = UIImage(cgImage: cgimg, scale: 1.0, orientation: UIImage.Orientation.right)
            
            // 文字列抽出
            //非同期処理を行う
            dispatchQueue.async {
                self.detectTextGoogle(image: afterImage)
            }
        }
    }
    /*******************************************************************
     ボタンタップ時の処理
     *******************************************************************/
    @IBAction func cancelBtnTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    @IBAction func shutterBtnTapped(_ sender: Any) {
        
        if UserDefaults.standard.object(forKey: "scanCount") == nil{
            UserDefaults.standard.set(SCAN_USE_NUM, forKey: "scanCount")
        }else{
            SCAN_USE_NUM = UserDefaults.standard.integer(forKey: "scanCount") + 1
            UserDefaults.standard.set(SCAN_USE_NUM, forKey: "scanCount")
        }
        Analytics.setUserProperty(String(SCAN_USE_NUM), forName: "スキャン回数")
        if SCAN_AD_INTERVAL != 0 {
            if SCAN_USE_NUM % SCAN_AD_INTERVAL == 0{
                if let interstitial = interstitial {
                    interstitial.present(from: self)
                } else {
                    dlog("Admob wasn't ready")
                    // 初期化
                    let interstitial_five = FADInterstitial(slotId: "252628")
                    interstitial_five?.loadAd()
                    if (interstitial_five?.state == kFADStateLoaded) {
                        UserDefaults.standard.set(SCAN_USE_NUM, forKey: "scanCount")
                        interstitial_five?.show()
                    }
                }
            }
        }
        dispatchQueue = DispatchQueue(label: "Dispatch Queue", attributes: [], target: nil)
        UIView.animate(withDuration: 0.1, animations: {
            //拡大縮小の処理
            self.shutterBtn.transform = CGAffineTransform(scaleX: 1/2, y: 1/2)
        })
        UIView.animate(withDuration: 0.3, animations: {
            //拡大縮小の処理
            self.shutterBtn.transform = CGAffineTransform(scaleX: 1, y: 1)
        })
        
        // カメラの設定
        let settingsForMonitoring = AVCapturePhotoSettings()
        let device = AVCaptureDevice.default(
            AVCaptureDevice.DeviceType.builtInWideAngleCamera,
            for: AVMediaType.video, // ビデオ入力
            position: AVCaptureDevice.Position.back)
        if !device!.hasFlash{
            settingsForMonitoring.flashMode = .off
        }else{
            switch flashSetting.selectedSegmentIndex {
            case 0:
                settingsForMonitoring.flashMode = .auto
            case 1:
                settingsForMonitoring.flashMode = .on
            case 2:
                settingsForMonitoring.flashMode = .off
            default:
                settingsForMonitoring.flashMode = .auto
            }
        }
        settingsForMonitoring.isAutoStillImageStabilizationEnabled = true
        settingsForMonitoring.isHighResolutionPhotoEnabled = false
        // 撮影
        stillImageOutput?.capturePhoto(with: settingsForMonitoring, delegate: self)
        waitViewWithAD.isHidden = false
        shutterBtn.isEnabled = false
    }

    /*******************************************************************
     Google Cloud Vision API関連の処理
     *******************************************************************/
    // APIに画像を渡して解析
    func detectTextGoogle(image : UIImage) {
        // 画像はbase64する
        if let base64image = image.pngData()?.base64EncodedString() {
            // リクエストの作成
            // 文字検出をしたいのでtypeにはTEXT_DETECTIONを指定する
            // 画像サイズの制限があるので本当は大きすぎたらリサイズしたりする必要がある
            let request: Parameters = [
                "requests": [
                    "image": [
                        "content": base64image
                    ],
                    "features": [
                        [
                            "type": "TEXT_DETECTION",
                            "maxResults": 1
                        ]
                    ]
                ]
            ]
            // Google Cloud PlatformのAPI Managerでキーを制限している場合、リクエストヘッダのX-Ios-Bundle-Identifierに指定した値を入れる
            let httpHeader: HTTPHeaders = [
                "Content-Type": "application/json",
                "X-Ios-Bundle-Identifier": Bundle.main.bundleIdentifier ?? ""
            ]
            // googleApiKeyにGoogle Cloud PlatformのAPI Managerで取得したAPIキーを入れる
            AF.request("https://vision.googleapis.com/v1/images:annotate?key=\(GOOGLE_VISION_API)", method: .post, parameters: request, encoding: JSONEncoding.default, headers: httpHeader).validate(statusCode: 200..<300).responseJSON { response in
                // レスポンスの処理
                if FROM_SCAN_CAMERA {
                    previewImageScanCaptured = image
                }else{
                    previewImageLyricCaptured = image
                }
                googleResult(response: response)
            }
        }
        // 解析結果の取得
        func googleResult(response: AFDataResponse<Any>) {
            guard let result = response.value else {
                // レスポンスが空っぽだったりしたら終了
                // アラートを作成
                let alert = UIAlertController(
                    title: localText(key:"text_err_failure"),
                    message: localText(key:"text_err_scan_failure_body"),
                    preferredStyle: .alert)
                // アラートにボタンをつける
                let action1 = UIAlertAction(title: localText(key:"text_err_scan_retry"), style: UIAlertAction.Style.default, handler: {
                    (action: UIAlertAction!) in
                    self.waitViewWithAD.isHidden = true
                    self.shutterBtn.isEnabled = true
                })
                let action2 = UIAlertAction(title: MESSAGE_CANCEL, style: UIAlertAction.Style.default, handler: {
                    (action: UIAlertAction!) in
                    self.waitViewWithAD.isHidden = true
                    self.shutterBtn.isEnabled = true
                    self.dismiss(animated: true, completion: nil)
                })
                alert.addAction(action1)
                alert.addAction(action2)
                // アラート表示
                present(alert, animated: true, completion: nil)
                return
            }
            let json = JSON(result)
            let annotations: JSON = json["responses"][0]["textAnnotations"]
            var detectedText: String = ""
            // 結果からdescriptionを取り出して一つの文字列にする
            annotations.forEach { (_, annotation) in
                detectedText += annotation["description"].string!
            }
            let splitDetectedText = detectedText.components(separatedBy: "\n")
            var resultDetectedText = ""
            if splitDetectedText.count > 1 {
                dlog(splitDetectedText.count)
                let resultIndex = splitDetectedText[splitDetectedText.count - 1].count + (splitDetectedText.count - 1)
                dlog(detectedText.startIndex)
                dlog(resultIndex)
                resultDetectedText = String(detectedText[detectedText.startIndex...detectedText.index(detectedText.startIndex, offsetBy: resultIndex)])
                if resultDetectedText == "" {
                    resultDetectedText = localText(key:"text_err_scan_failure_title")
                }
            }else{
                resultDetectedText = localText(key:"text_err_scan_nochara")
            }
            ///resultDetectedText = resultDetectedText
            // 結果を表示する
            if FROM_SCAN_CAMERA {
                CAMERAVIEW_RESULT_TEXT = resultDetectedText
                FROM_SCAN_CAMERA = false
                self.dismiss(animated: true, completion: nil)
            }else{
                CAMERAVIEW_LYRIC_RESULT_TEXT = resultDetectedText
                FROM_SCAN_CAMERA = false
                self.dismiss(animated: true, completion: nil)
            }
            waitViewWithAD.isHidden = true
            shutterBtn.isEnabled = true
        }
    }
    /*******************************************************************
     広告関連の処理
     *******************************************************************/
    func adViewDidFail(toLoad view: AmazonAdView!, withError: AmazonAdError!) -> Void {
        dlog("Ad Failed to load. Error code \(withError.errorCode): \(String(describing: withError.errorDescription))")
    }
    
    func adViewWillExpand(_ view: AmazonAdView!) -> Void {
        dlog("Ad will expand")
    }
    
    func adViewDidCollapse(_ view: AmazonAdView!) -> Void {
        dlog("Ad has collapsed")
    }
    
    // Five
    var fadDelegate:FADDelegate!
    func fiveAdDidReplay(_ ad: FADAdInterface!) {
        dlog(FADAdInterface.self)
    }
    
    func fiveAdDidViewThrough(_ ad: FADAdInterface!) {
        dlog(FADAdInterface.self)
        
    }
    
    func fiveAdDidResume(_ ad: FADAdInterface!) {
        dlog(FADAdInterface.self)
    }
    
    func fiveAdDidPause(_ ad: FADAdInterface!) {
        dlog(FADAdInterface.self)
    }
    func fiveAdDidStart(_ ad: FADAdInterface!) {
        dlog(FADAdInterface.self)
    }
    
    func fiveAdDidClose(_ ad: FADAdInterface!) {
        dlog(FADAdInterface.self)
    }
    
    func fiveAdDidClick(_ ad: FADAdInterface!) {
        dlog(FADAdInterface.self)
    }
    
    func fiveAd(_ ad: FADAdInterface!, didFailedToReceiveAdWithError errorCode: FADErrorCode) {
        dlog(errorCode)
    }
    
    func fiveAdDidLoad(_ ad: FADAdInterface!) {
        dlog(FADAdInterface.self)
    }
    // 必ず実装してください。
    // AmazonAdViewDelegate APVAdManagerDelegate で使う
    func viewControllerForPresentingModalView() -> UIViewController! {
        return self
    }
    func onReady(toPlayAd ad: APVAdManager!, for nativeAd: APVNativeAd!) {
//        ad.showAd(for: aPVAd)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
//        self.timer.invalidate()
//        timer.invalidate()
    }
}
