//
//  AdmobNativeAD.swift
//  musica
//
//  Created by 栗林貴大 on 2019/10/27.
//  Copyright © 2019 K.T. All rights reserved.
//

import Foundation
import GoogleMobileAds
/*******************************************************************
HOME画面のAD処理
*******************************************************************/
extension HomeAreaViewController : VideoControllerDelegate , NativeAdDelegate, NativeAdLoaderDelegate {
    
    func createView() -> UIView{
        let view = UIView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height))
        let logoView = UIImageView()
        logoView.image = UIImage(named : "logo_with_title")
        logoView.frame.size = CGSize(width: 120,height: 120)
        logoView.center = self.view.center
        view.addSubview(logoView)
        if #available(iOS 13.0, *) {
            view.backgroundColor = UIColor.systemBackground
        } else {
            view.backgroundColor = UIColor.white
        }
        return view
    }
    
    func setAdView(_ view: NativeAdView) {
        let multipleAdsOptions = MultipleAdsAdLoaderOptions()
        multipleAdsOptions.numberOfAds = 1
        adLoader = AdLoader(adUnitID: ADMOB_NATIVE_ADVANCE, rootViewController: self,
            adTypes: [AdLoaderAdType.native],
            options: [multipleAdsOptions])
        adLoader.delegate = self
        nativeAdView = view
        nativeAdView.translatesAutoresizingMaskIntoConstraints = true

        nativeAdView.frame =  CGRect(x: 0, y: 0 , width: Int(myAppFrameSize.width),height: Int(myAppFrameSize.width) * 11 / 16 )
        adLoader.load(Request())
    }
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
    }

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        nativeAdView.nativeAd = nativeAd

        nativeAd.delegate = self

        heightConstraint?.isActive = false
        (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline
        nativeAdView.mediaView?.mediaContent = nativeAd.mediaContent

        if nativeAd.mediaContent.hasVideoContent {
          let controller = nativeAd.mediaContent.videoController
          controller.delegate = self
                    controller.isMuted = true
                    controller.play()
        }
        if let mediaView = nativeAdView.mediaView, nativeAd.mediaContent.aspectRatio > 0 {
          heightConstraint = NSLayoutConstraint(item: mediaView,
                                                attribute: .height,
                                                relatedBy: .equal,
                                                toItem: mediaView,
                                                attribute: .width,
                                                multiplier: CGFloat(1 / nativeAd.mediaContent.aspectRatio),
                                                constant: 0)
          heightConstraint?.isActive = true
        }
        (nativeAdView.bodyView as? UILabel)?.text = nativeAd.body
        nativeAdView.bodyView?.isHidden = nativeAd.body == nil

        (nativeAdView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        nativeAdView.callToActionView?.isHidden = nativeAd.callToAction == nil

        (nativeAdView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        nativeAdView.iconView?.isHidden = nativeAd.icon == nil
        nativeAdView.iconView?.contentMode = .scaleAspectFill
        nativeAdView.mediaView?.contentMode = .scaleAspectFit
        nativeAdView.starRatingView?.isHidden = nativeAd.starRating == nil

        (nativeAdView.storeView as? UILabel)?.text = nativeAd.store
        nativeAdView.storeView?.isHidden = nativeAd.store == nil

        (nativeAdView.priceView as? UILabel)?.text = nativeAd.price
        nativeAdView.priceView?.isHidden = nativeAd.price == nil

        (nativeAdView.advertiserView as? UILabel)?.text = nativeAd.advertiser
        nativeAdView.advertiserView?.isHidden = nativeAd.advertiser == nil

        // In order for the SDK to process touch events properly, user interaction should be disabled.
        nativeAdView.callToActionView?.isUserInteractionEnabled = false
        nativeAdView.frame =  CGRect(x: 0, y: 0 , width: Int(myAppFrameSize.width),height: Int(myAppFrameSize.width) * 11 / 16 )

        myADView.addSubview(nativeAdView)
    }
    func nativeAdDidRecordImpression(_ nativeAd: NativeAd) {}
    func nativeAdDidRecordClick(_ nativeAd: NativeAd) {}
    func nativeAdWillPresentScreen(_ nativeAd: NativeAd) {}
    func nativeAdWillDismissScreen(_ nativeAd: NativeAd) {}
    func nativeAdDidDismissScreen(_ nativeAd: NativeAd) {}
    func nativeAdWillLeaveApplication(_ nativeAd: NativeAd) {}
}
/*******************************************************************
ランキング画面のAD処理
*******************************************************************/
extension ITuneRankingViewController : VideoControllerDelegate , NativeAdDelegate, NativeAdLoaderDelegate {
    func setAdView(_ view: NativeAdView,adUnitID: String = "") {
        if adUnitID == ADMOB_NATIVE_ADVANCE_DIALOG_RECOMMEND{
            let multipleAdsOptions = MultipleAdsAdLoaderOptions()
            adDialogLoader = AdLoader(adUnitID: adUnitID, rootViewController: self,
                adTypes: [AdLoaderAdType.native],
                options: [multipleAdsOptions])
            if nativeAdDialogView == nil{
                nativeAdDialogView = view
                myADViewDialog.addSubview(nativeAdDialogView!)
            }
            nativeAdDialogView = view
            nativeAdDialogView!.translatesAutoresizingMaskIntoConstraints = true
            nativeAdDialogView?.frame = CGRect(x: 0, y: 0 , width: myAppFrameSize.width - 32 ,height:(myAppFrameSize.width - 32) * 15/32 + 70)
            adDialogLoader.delegate = self
            adDialogLoader.load(Request())
        }else if adUnitID == ADMOB_NATIVE_ADVANCE_RANKING{
            let ImageV = UIImageView()
            ImageV.contentMode = .center
            ImageV.frame =  CGRect(x: 0, y: 0 , width: Int(myAppFrameSize.width),height: Int(myAppFrameSize.width) * 11 / 16 )
            ImageV.backgroundColor = darkModeNaviWhiteUIcolor()
            ImageV.image = UIImage(named: "homeicon_720")
            myADView.backgroundColor = darkModeNaviWhiteUIcolor()
            myADView.addSubview(ImageV)
            let multipleAdsOptions = MultipleAdsAdLoaderOptions()
            multipleAdsOptions.numberOfAds = 1
            adHederLoader = AdLoader(adUnitID: adUnitID, rootViewController: self,
                adTypes: [AdLoaderAdType.native],
                options: [multipleAdsOptions])
            adHederLoader.delegate = self
            nativeAdView = view
            nativeAdView.translatesAutoresizingMaskIntoConstraints = true

            nativeAdView.frame =  CGRect(x: 0, y: 0 , width: Int(myAppFrameSize.width),height: Int(myAppFrameSize.width) * 11 / 16 )
            adHederLoader.load(Request())
        }
    }
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
    }

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        dlog(adLoader.adUnitID)
        if adLoader.adUnitID == ADMOB_NATIVE_ADVANCE_DIALOG_RECOMMEND{
            nativeAd.delegate = self
            nativeAdDialogView!.nativeAd = nativeAd
            (nativeAdDialogView!.headlineView as? UILabel)?.text = nativeAd.headline
            nativeAdDialogView!.mediaView?.mediaContent = nativeAd.mediaContent
            if let mediaView = nativeAdDialogView!.mediaView, nativeAd.mediaContent.aspectRatio > 0 {
                heightConstraint = NSLayoutConstraint(item: mediaView,
                                                      attribute: .height,
                                                      relatedBy: .equal,
                                                      toItem: mediaView,
                                                      attribute: .width,
                                                      multiplier: CGFloat(1 / nativeAd.mediaContent.aspectRatio),
                                                      constant: 0)
                heightConstraint?.isActive = true
            }
            (nativeAdDialogView!.bodyView as? UILabel)?.text = nativeAd.body
            nativeAdDialogView!.bodyView?.isHidden = nativeAd.body == nil
            (nativeAdDialogView!.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
            nativeAdDialogView!.callToActionView?.isHidden = nativeAd.callToAction == nil
            (nativeAdDialogView!.iconView as? UIImageView)?.image = nativeAd.icon?.image
            nativeAdDialogView!.iconView?.isHidden = nativeAd.icon == nil
            nativeAdDialogView!.iconView?.contentMode = .scaleAspectFill
            nativeAdDialogView!.starRatingView?.isHidden = nativeAd.starRating == nil
            (nativeAdDialogView!.storeView as? UILabel)?.text = nativeAd.store
            nativeAdDialogView!.storeView?.isHidden = nativeAd.store == nil
            (nativeAdDialogView!.priceView as? UILabel)?.text = nativeAd.price
            nativeAdDialogView!.priceView?.isHidden = nativeAd.price == nil
//            popupView.baseAdView.frame = CGRect(x: 0, y: 0 , width: myAppFrameSize.width - 32 ,height:(myAppFrameSize.width - 32) * 15/32 + 70)
            (nativeAdDialogView!.advertiserView as? UILabel)?.text = nativeAd.advertiser
            nativeAdDialogView!.advertiserView?.isHidden = nativeAd.advertiser == nil
            nativeAdDialogView!.mediaView?.contentMode = .scaleAspectFit
            nativeAdDialogView!.callToActionView?.isUserInteractionEnabled = false
//            if myADViewDialog.isDescendant(of: nativeAdDialogView!){
//                myADViewDialog.removeFromSuperview()
//                myADViewDialog.addSubview(nativeAdDialogView!)
//            }else{
//                myADViewDialog.addSubview(nativeAdDialogView!)
//            }
        }else if adLoader.adUnitID  == ADMOB_NATIVE_ADVANCE_RANKING{
            nativeAdView.nativeAd = nativeAd
            nativeAd.delegate = self
            heightConstraint?.isActive = false
            (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline
            nativeAdView.mediaView?.mediaContent = nativeAd.mediaContent
            if nativeAd.mediaContent.hasVideoContent {
          let controller = nativeAd.mediaContent.videoController
          controller.delegate = self
                        controller.isMuted = true
              controller.play()
            }
            else {
            }
            if let mediaView = nativeAdView.mediaView, nativeAd.mediaContent.aspectRatio > 0 {
              heightConstraint = NSLayoutConstraint(item: mediaView,
                                                    attribute: .height,
                                                    relatedBy: .equal,
                                                    toItem: mediaView,
                                                    attribute: .width,
                                                    multiplier: CGFloat(1 / nativeAd.mediaContent.aspectRatio),
                                                    constant: 0)
              heightConstraint?.isActive = true
            }
            (nativeAdView.bodyView as? UILabel)?.text = nativeAd.body
            nativeAdView.bodyView?.isHidden = nativeAd.body == nil

            (nativeAdView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
            nativeAdView.callToActionView?.isHidden = nativeAd.callToAction == nil

            (nativeAdView.iconView as? UIImageView)?.image = nativeAd.icon?.image
            nativeAdView.iconView?.isHidden = nativeAd.icon == nil
            nativeAdView.iconView?.contentMode = .scaleAspectFill
            nativeAdView.mediaView?.contentMode = .scaleAspectFit
            nativeAdView.starRatingView?.isHidden = nativeAd.starRating == nil

            (nativeAdView.storeView as? UILabel)?.text = nativeAd.store
            nativeAdView.storeView?.isHidden = nativeAd.store == nil

            (nativeAdView.priceView as? UILabel)?.text = nativeAd.price
            nativeAdView.priceView?.isHidden = nativeAd.price == nil

            (nativeAdView.advertiserView as? UILabel)?.text = nativeAd.advertiser
            nativeAdView.advertiserView?.isHidden = nativeAd.advertiser == nil

            // In order for the SDK to process touch events properly, user interaction should be disabled.
            nativeAdView.callToActionView?.isUserInteractionEnabled = false
            nativeAdView.frame =  CGRect(x: 0, y: 0 , width: Int(myAppFrameSize.width),height: Int(myAppFrameSize.width) * 11 / 16 )
            myADView.addSubview(nativeAdView)
            if nativeAd.mediaContent.hasVideoContent {
          let controller = nativeAd.mediaContent.videoController
                controller.delegate = self
                controller.isMuted = true
                controller.play()
            }
        }
    }
    func nativeAdDidRecordImpression(_ nativeAd: NativeAd) {}
    func nativeAdDidRecordClick(_ nativeAd: NativeAd) {}
    func nativeAdWillPresentScreen(_ nativeAd: NativeAd) {}
    func nativeAdWillDismissScreen(_ nativeAd: NativeAd) {
        adHederLoader.load(Request())
        adDialogLoader.load(Request())
    }
    func nativeAdDidDismissScreen(_ nativeAd: NativeAd) {}
    func nativeAdWillLeaveApplication(_ nativeAd: NativeAd) {}
}
/*******************************************************************
 ランキング検索結果画面のAD処理
 *******************************************************************/
extension iTuneRankingContentsListViewController : VideoControllerDelegate , NativeAdDelegate, NativeAdLoaderDelegate {
    func setAdView(_ view: NativeAdView) {
      // Remove the previous ad view.
        let multipleAdsOptions = MultipleAdsAdLoaderOptions()
        multipleAdsOptions.numberOfAds = 1
        adLoader = AdLoader(adUnitID: ADMOB_NATIVE_ADVANCE_RANKING_CONTENTS, rootViewController: self,
          adTypes: [AdLoaderAdType.native],
          options: [multipleAdsOptions])
        nativeAdView = view
        nativeAdView.translatesAutoresizingMaskIntoConstraints = true

        nativeAdView.frame =  CGRect(x: 0, y: 0 , width: Int(myAppFrameSize.width),height:90 )

        adLoader.delegate = self
        let req = Request()
        adLoader.load(req)
    }
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
    }

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        nativeAdView.nativeAd = nativeAd

        // Set ourselves as the native ad delegate to be notified of native ad events.
        nativeAd.delegate = self

        // Deactivate the height constraint that was set when the previous video ad loaded.
        heightConstraint?.isActive = false

        // Populate the native ad view with the native ad assets.
        // The headline and mediaContent are guaranteed to be present in every native ad.
        (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline
        nativeAdView.mediaView?.mediaContent = nativeAd.mediaContent

        if nativeAd.mediaContent.hasVideoContent {
          let controller = nativeAd.mediaContent.videoController
          // By acting as the delegate to the GADVideoController, this ViewController receives messages
          // about events in the video lifecycle.
          controller.delegate = self
          controller.isMuted = true
          controller.play()
//          videoStatusLabel.text = "Ad contains a video asset."
        }
        else {
//          videoStatusLabel.text = "Ad does not contain a video."
        }

        if let mediaView = nativeAdView.mediaView, nativeAd.mediaContent.aspectRatio > 0 {
          heightConstraint = NSLayoutConstraint(item: mediaView,
                                                attribute: .height,
                                                relatedBy: .equal,
                                                toItem: mediaView,
                                                attribute: .width,
                                                multiplier: CGFloat(1 / nativeAd.mediaContent.aspectRatio),
                                                constant: 0)
          heightConstraint?.isActive = true
        }

        // These assets are not guaranteed to be present. Check that they are before
        // showing or hiding them.
        (nativeAdView.bodyView as? UILabel)?.text = nativeAd.body
        nativeAdView.bodyView?.isHidden = nativeAd.body == nil

        (nativeAdView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        nativeAdView.callToActionView?.isHidden = nativeAd.callToAction == nil

        (nativeAdView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        nativeAdView.iconView?.isHidden = nativeAd.icon == nil
        nativeAdView.iconView?.contentMode = .scaleAspectFill
        nativeAdView.mediaView?.contentMode = .scaleAspectFit
//        (nativeAdView.starRatingView as? UIImageView)?.image = imageOfStars(from:nativeAd.starRating)
        nativeAdView.starRatingView?.isHidden = nativeAd.starRating == nil

        (nativeAdView.storeView as? UILabel)?.text = nativeAd.store
        nativeAdView.storeView?.isHidden = nativeAd.store == nil

        (nativeAdView.priceView as? UILabel)?.text = nativeAd.price
        nativeAdView.priceView?.isHidden = nativeAd.price == nil

        (nativeAdView.advertiserView as? UILabel)?.text = nativeAd.advertiser
        nativeAdView.advertiserView?.isHidden = nativeAd.advertiser == nil

        // In order for the SDK to process touch events properly, user interaction should be disabled.
        nativeAdView.callToActionView?.isUserInteractionEnabled = false
        nativeAdView.frame =  CGRect(x: 0, y: 0 , width: Int(myAppFrameSize.width),height:90)
        myADView.frame =  CGRect(x: 0, y: 0 , width: Int(myAppFrameSize.width),height:90)
        myADView.addSubview(nativeAdView)
    }
    func nativeAdDidRecordClick(_ nativeAd: NativeAd) {}
    func nativeAdDidRecordImpression(_ nativeAd: NativeAd) {}
    func nativeAdWillPresentScreen(_ nativeAd: NativeAd) {}
    func nativeAdWillDismissScreen(_ nativeAd: NativeAd) {}
    func nativeAdDidDismissScreen(_ nativeAd: NativeAd) {}
    func nativeAdWillLeaveApplication(_ nativeAd: NativeAd) {}
}
/*******************************************************************
 検索結果画面のAD処理
 *******************************************************************/
extension SearchViewController : VideoControllerDelegate , NativeAdDelegate, NativeAdLoaderDelegate {
    func setAdView(_ view: NativeAdView ,adUnitID:String) {
      // Remove the previous ad view.
        if adUnitID == ADMOB_NATIVE_ADVANCE_SEARCH_RECOMMEND{
            let multipleAdsOptions = MultipleAdsAdLoaderOptions()
            multipleAdsOptions.numberOfAds = 1
            adCollectLoader = AdLoader(adUnitID: adUnitID, rootViewController: self,
              adTypes: [AdLoaderAdType.native],
              options: [multipleAdsOptions])
            nativeAdRecommendView = view
            nativeAdRecommendView.translatesAutoresizingMaskIntoConstraints = true
            
            adCollectLoader.delegate = self
            adCollectLoader.load(Request())
        }else if adUnitID == ADMOB_NATIVE_ADVANCE_DIALOG_RECOMMEND{
            let multipleAdsOptions = MultipleAdsAdLoaderOptions()
            adDialogLoader = AdLoader(adUnitID: adUnitID, rootViewController: self,
                adTypes: [AdLoaderAdType.native],
                options: [multipleAdsOptions])
            if nativeAdDialogView == nil{
                nativeAdDialogView = view
                myADViewDialog.addSubview(nativeAdDialogView!)
            }
            nativeAdDialogView = view
            nativeAdDialogView.translatesAutoresizingMaskIntoConstraints = true
            nativeAdDialogView.frame = CGRect(x: 0, y: 0 , width: myAppFrameSize.width - 32 ,height:(myAppFrameSize.width - 32) * 15/32 + 70)
            
            nativeAdDialogView?.frame = CGRect(x: 0, y: 0 , width: myAppFrameSize.width - 32 ,height:(myAppFrameSize.width - 32) * 15/32 + 70)
            adDialogLoader.delegate = self
            let req = Request()
            adDialogLoader.load(req)
        }
    }
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
    }

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        
        heightConstraint?.isActive = false
        if adLoader.adUnitID == ADMOB_NATIVE_ADVANCE_SEARCH_RECOMMEND{
            nativeAd.delegate = self
            nativeAdRecommendView.nativeAd = nativeAd
            (nativeAdRecommendView.headlineView as? UILabel)?.text = nativeAd.headline
            nativeAdRecommendView.mediaView?.mediaContent = nativeAd.mediaContent
            if let mediaView = nativeAdRecommendView.mediaView, nativeAd.mediaContent.aspectRatio > 0 {
                let path = UIBezierPath(roundedRect: mediaView.bounds, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 12, height: 12))
                let mask = CAShapeLayer()
                mask.path = path.cgPath
                mediaView.layer.mask = mask
                //heightConstraint?.isActive = true
            }
            (nativeAdRecommendView.bodyView as? UILabel)?.text = nativeAd.body
            nativeAdRecommendView.bodyView?.isHidden = nativeAd.body == nil
            (nativeAdRecommendView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
            nativeAdRecommendView.callToActionView?.isHidden = nativeAd.callToAction == nil
            (nativeAdRecommendView.iconView as? UIImageView)?.image = nativeAd.icon?.image
            nativeAdRecommendView.iconView?.isHidden = nativeAd.icon == nil
            nativeAdRecommendView.iconView?.contentMode = .scaleAspectFill
            nativeAdRecommendView.starRatingView?.isHidden = nativeAd.starRating == nil
            (nativeAdRecommendView.storeView as? UILabel)?.text = nativeAd.store
            nativeAdRecommendView.storeView?.isHidden = nativeAd.store == nil
            (nativeAdRecommendView.priceView as? UILabel)?.text = nativeAd.price
            nativeAdRecommendView.priceView?.isHidden = nativeAd.price == nil
            (nativeAdRecommendView.advertiserView as? UILabel)?.text = nativeAd.advertiser
            nativeAdRecommendView.advertiserView?.isHidden = nativeAd.advertiser == nil
            nativeAdRecommendView.frame =  CGRect(x: 0, y: 0 , width: 174 ,height:174)
            myADViewRecomend.frame =  CGRect(x: 0, y: 0 , width: 174 ,height:174)
            nativeAdRecommendView.mediaView?.contentMode = .scaleAspectFit
            nativeAdRecommendView.callToActionView?.isUserInteractionEnabled = false
            if myADViewRecomend.isDescendant(of: nativeAdRecommendView){
                myADViewRecomend.removeFromSuperview()
                myADViewRecomend.addSubview(nativeAdRecommendView)
            }else{
                myADViewRecomend.addSubview(nativeAdRecommendView)
            }
            
        }else if adLoader.adUnitID == ADMOB_NATIVE_ADVANCE_DIALOG_RECOMMEND{
            nativeAd.delegate = self
            nativeAdDialogView.nativeAd = nativeAd
            (nativeAdDialogView.headlineView as? UILabel)?.text = nativeAd.headline
            nativeAdDialogView.mediaView?.mediaContent = nativeAd.mediaContent
            if let mediaView = nativeAdDialogView.mediaView, nativeAd.mediaContent.aspectRatio > 0 {
                heightConstraint = NSLayoutConstraint(item: mediaView,
                                                      attribute: .height,
                                                      relatedBy: .equal,
                                                      toItem: mediaView,
                                                      attribute: .width,
                                                      multiplier: CGFloat(1 / nativeAd.mediaContent.aspectRatio),
                                                      constant: 0)
                heightConstraint?.isActive = true
            }
            (nativeAdDialogView.bodyView as? UILabel)?.text = nativeAd.body
            nativeAdDialogView.bodyView?.isHidden = nativeAd.body == nil
            (nativeAdDialogView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
            nativeAdDialogView.callToActionView?.isHidden = nativeAd.callToAction == nil
            (nativeAdDialogView.iconView as? UIImageView)?.image = nativeAd.icon?.image
            nativeAdDialogView.iconView?.isHidden = nativeAd.icon == nil
            nativeAdDialogView.iconView?.contentMode = .scaleAspectFill
            nativeAdDialogView.starRatingView?.isHidden = nativeAd.starRating == nil
            (nativeAdDialogView.storeView as? UILabel)?.text = nativeAd.store
            nativeAdDialogView.storeView?.isHidden = nativeAd.store == nil
            (nativeAdDialogView.priceView as? UILabel)?.text = nativeAd.price
            nativeAdDialogView.priceView?.isHidden = nativeAd.price == nil
            popupView.baseAdView.frame = CGRect(x: 0, y: 0 , width: myAppFrameSize.width - 32 ,height:(myAppFrameSize.width - 32) * 15/32 + 70)
            myADViewDialog.frame =  CGRect(x: 0, y: 0 , width: myAppFrameSize.width - 32 ,height:(myAppFrameSize.width - 32) * 15/32 + 70)
            (nativeAdDialogView.advertiserView as? UILabel)?.text = nativeAd.advertiser
            nativeAdDialogView.advertiserView?.isHidden = nativeAd.advertiser == nil
            nativeAdDialogView.mediaView?.contentMode = .scaleAspectFit
            nativeAdDialogView.callToActionView?.isUserInteractionEnabled = false
//            if myADViewDialog.isDescendant(of: nativeAdDialogView){
//                myADViewDialog.removeFromSuperview()
//                myADViewDialog.addSubview(nativeAdDialogView)
//            }else{
//                myADViewDialog.addSubview(nativeAdDialogView)
//            }
        }
        if nativeAd.mediaContent.hasVideoContent {
          let controller = nativeAd.mediaContent.videoController
            controller.delegate = self
            controller.isMuted = true
                      controller.play()
        }
    }
    func nativeAdDidRecordClick(_ nativeAd: NativeAd) {}
    func nativeAdDidRecordImpression(_ nativeAd: NativeAd) {}
    func nativeAdWillPresentScreen(_ nativeAd: NativeAd) {}
    func nativeAdWillDismissScreen(_ nativeAd: NativeAd) {}
    func nativeAdDidDismissScreen(_ nativeAd: NativeAd) {}
    func nativeAdWillLeaveApplication(_ nativeAd: NativeAd) {
        popupView.removeFromSuperview()
    }
}
/*******************************************************************
 設定画面のAD処理
 *******************************************************************/
extension SettingViewController : VideoControllerDelegate , NativeAdDelegate, NativeAdLoaderDelegate {
    func setAdView(_ view: NativeAdView) {
      // Remove the previous ad view.
        let multipleAdsOptions = MultipleAdsAdLoaderOptions()
        multipleAdsOptions.numberOfAds = 1
        adLoader = AdLoader(adUnitID: ADMOB_NATIVE_ADVANCE_SETTINGS, rootViewController: self,
          adTypes: [AdLoaderAdType.native],
          options: [multipleAdsOptions])
        nativeAdView = view
        nativeAdView.translatesAutoresizingMaskIntoConstraints = true

        nativeAdView.frame =  CGRect(x: 0, y: 0 , width: Int(myAppFrameSize.width),height:Int(myAppFrameSize.width) * 11 / 16  )

        adLoader.delegate = self
        let req = Request()
        adLoader.load(req)
    }
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
    }

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        nativeAdView.nativeAd = nativeAd

        // Set ourselves as the native ad delegate to be notified of native ad events.
        nativeAd.delegate = self

        // Deactivate the height constraint that was set when the previous video ad loaded.
        heightConstraint?.isActive = false

        // Populate the native ad view with the native ad assets.
        // The headline and mediaContent are guaranteed to be present in every native ad.
        (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline
        nativeAdView.mediaView?.mediaContent = nativeAd.mediaContent

        // Some native ads will include a video asset, while others do not. Apps can use the
        // GADVideoController's hasVideoContent property to determine if one is present, and adjust their
        // UI accordingly.
        if nativeAd.mediaContent.hasVideoContent {
          let controller = nativeAd.mediaContent.videoController
          // By acting as the delegate to the GADVideoController, this ViewController receives messages
          // about events in the video lifecycle.
          controller.delegate = self
//          videoStatusLabel.text = "Ad contains a video asset."
        }
        else {
//          videoStatusLabel.text = "Ad does not contain a video."
        }

        // This app uses a fixed width for the GADMediaView and changes its height to match the aspect
        // ratio of the media it displays.
        if let mediaView = nativeAdView.mediaView, nativeAd.mediaContent.aspectRatio > 0 {
          heightConstraint = NSLayoutConstraint(item: mediaView,
                                                attribute: .height,
                                                relatedBy: .equal,
                                                toItem: mediaView,
                                                attribute: .width,
                                                multiplier: CGFloat(1 / nativeAd.mediaContent.aspectRatio),
                                                constant: 0)
          heightConstraint?.isActive = true
        }

        // These assets are not guaranteed to be present. Check that they are before
        // showing or hiding them.
        (nativeAdView.bodyView as? UILabel)?.text = nativeAd.body
        nativeAdView.bodyView?.isHidden = nativeAd.body == nil

        (nativeAdView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        nativeAdView.callToActionView?.isHidden = nativeAd.callToAction == nil

        (nativeAdView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        nativeAdView.iconView?.isHidden = nativeAd.icon == nil
        nativeAdView.iconView?.contentMode = .scaleAspectFill
        nativeAdView.mediaView?.contentMode = .scaleAspectFit
//        (nativeAdView.starRatingView as? UIImageView)?.image = imageOfStars(from:nativeAd.starRating)
        nativeAdView.starRatingView?.isHidden = nativeAd.starRating == nil

        (nativeAdView.storeView as? UILabel)?.text = nativeAd.store
        nativeAdView.storeView?.isHidden = nativeAd.store == nil

        (nativeAdView.priceView as? UILabel)?.text = nativeAd.price
        nativeAdView.priceView?.isHidden = nativeAd.price == nil

        (nativeAdView.advertiserView as? UILabel)?.text = nativeAd.advertiser
        nativeAdView.advertiserView?.isHidden = nativeAd.advertiser == nil

        // In order for the SDK to process touch events properly, user interaction should be disabled.
        nativeAdView.callToActionView?.isUserInteractionEnabled = false

        // おすすめアプリセクションのヘッダーとして表示するためフラグを立ててリロード
        nativeAdIsLoaded = true
        DispatchQueue.main.async {
            self.table.reloadData()
        }
    }
    func nativeAdDidRecordClick(_ nativeAd: NativeAd) {}
    func nativeAdDidRecordImpression(_ nativeAd: NativeAd) {}
    func nativeAdWillPresentScreen(_ nativeAd: NativeAd) {}
    func nativeAdWillDismissScreen(_ nativeAd: NativeAd) {}
    func nativeAdDidDismissScreen(_ nativeAd: NativeAd) {}
    func nativeAdWillLeaveApplication(_ nativeAd: NativeAd) {}
}

