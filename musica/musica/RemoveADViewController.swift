//
//  RemoveADViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2019/05/12.
//  Copyright © 2019 K.T. All rights reserved.
//

import UIKit
import SwiftyStoreKit

class RemoveADViewController: UIViewController {

    @IBOutlet weak var ruleKakin: UITextView!
    @IBAction func termsPPBtnTapped(_ sender: Any) {
        site = PP_TITLE
        performSegue(withIdentifier: "toPp",sender: "")
    }
    @IBOutlet weak var waitView: UIView!
    @IBOutlet weak var optionTextView: UITextView!
    @IBOutlet weak var removeADBtn: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        waitView.isHidden = true
        UserDefaults.standard.set("true", forKey: "kakinn_tap")
        ruleKakin.text = localText(key:"kakin_rule")
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        optionTextView.setContentOffset(CGPoint.zero, animated: false)
    }
    /*******************************************************************
     ボタンタップ時の処理
     *******************************************************************/
    override func viewWillAppear(_ animated: Bool) {
         // 動画は一旦止める
         if AVPlayerViewControllerManager.shared.controller.player != nil {
             AVPlayerViewControllerManager.shared.controller.player?.pause()
         }
         selectMusicView.isHidden = true
    }
    @IBAction func removeADBtnTapped(_ sender: Any) {
        waitView.isHidden = false
        showKakinAlert()
    }
    @IBAction func restoreBtnTapped(_ sender: Any) {
        self.waitView.isHidden = false
        SwiftyStoreKit.restorePurchases(atomically: true) { result in
            for product in result.restoredPurchases {
                if product.needsFinishTransaction {
                    SwiftyStoreKit.finishTransaction(product.transaction)
                }
            }
            self.waitView.isHidden = true
            if result.restoredPurchases.count > 0 {
                // リストア成功
                KAKIN_FLG = true
                UserDefaults.standard.set(KAKIN_FLG, forKey: "kakin")
                UserDefaults.standard.synchronize()
                deleteAD()
                let alert = UIAlertController(
                    title: localText(key:"kakin_restore"),
                    message: "" ,
                    preferredStyle: .alert)
                // アラートにボタンをつける
                alert.addAction(UIAlertAction(title: MESSAGE_OK, style: .default, handler: { action in
                    softwareReset()
                }))
                // アラート表示
                getForegroundViewController().present(alert, animated: true, completion: nil)
            }else{
                // リストア失敗
                let alert = UIAlertController(
                    title: localText(key:"kakin_restore_fail_title"),
                    message: localText(key:"kakin_restore_fail_body"),
                    preferredStyle: .alert)
                // アラートにボタンをつける
                alert.addAction(UIAlertAction(title: MESSAGE_OK, style: .default))
                // アラート表示
                getForegroundViewController().present(alert, animated: true, completion: nil)
            }
        }
    }
    /*******************************************************************
     更新型課金の処理
     *******************************************************************/
    func showKakinAlert(){
        if ADApearFlg() == false{
            self.purchase(PRODUCT_ID:"kuriFCTmusica")
        }else{
            // アラートを作成
            let alert = UIAlertController(title: SETTING_AD_CLEAR_TITLE,message: KAKINPLICE_PLICE,preferredStyle: .alert)
            // アラートにボタンをつける
            alert.addAction(UIAlertAction(title: MESSAGE_YES, style: .default, handler: { action in
                self.purchase(PRODUCT_ID:"kuriFCTmusica")
            }))// アラートにボタンをつける
            alert.addAction(UIAlertAction(title: MESSAGE_CANCEL, style: .default, handler: { action in
                DispatchQueue.main.async {
                    self.waitView.isHidden = true
                }
            }))
            // アラート表示
            present(alert, animated: true, completion: nil)
        }
    }
    func purchase(PRODUCT_ID:String){
        SwiftyStoreKit.purchaseProduct(PRODUCT_ID, quantity: 1, atomically: true) { result in
            switch result {
            case .success(_):
                //購入成功・購入の検証
                self.verifyPurchase(PRODUCT_ID: PRODUCT_ID)
            case .error(_):
                // キャンセル時に呼ばれる
                DispatchQueue.main.async {
                    self.waitView.isHidden = true
                }
            }
        }
    }
    
    func verifyPurchase(PRODUCT_ID:String){
        var successFlg = false
        let appleValidator = AppleReceiptValidator(service: .production, sharedSecret: SECRET_CODE)
        SwiftyStoreKit.verifyReceipt(using: appleValidator) { result in
            switch result {
            case .success(let receipt):
                //自動更新
                let purchaseResult = SwiftyStoreKit.verifySubscription(
                    ofType: .autoRenewable,
                    productId: PRODUCT_ID,
                    inReceipt: receipt)
                
                switch purchaseResult {
                case .purchased:
                    successFlg = true
                    deleteAD()
                    KAKIN_FLG = true
                    settingSectionTitle = settingSectionTitle_kakin
                    settingSectionData = settingSectionData_kakin
                case .notPurchased:
                    successFlg = false
                default:break
                }
            case .error:
                successFlg = false
                
            }
            if successFlg {
                // 成功
                KAKIN_FLG = true
                UserDefaults.standard.set(KAKIN_FLG, forKey: "kakin")
                UserDefaults.standard.synchronize()
                deleteAD()
                softwareReset()
            }else{
                // 失敗
            }
            DispatchQueue.main.async {
                self.waitView.isHidden = true
            }
        }
    }
    
}
