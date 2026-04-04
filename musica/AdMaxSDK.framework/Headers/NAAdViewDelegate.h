//
//  NAAdViewDelegate.h
//  admax
//
//  Created by ninja_kosuge on 2014/08/27.
//  Copyright (c) 2014年 SamuraiFactory. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NAAdView;

@protocol NAAdViewDelegate <NSObject>
@optional
- (void)adViewWillStartRequest;
@optional
- (void)adViewDidReceiveAd:(NAAdView *)adView;
@optional
- (void)adViewDidClickAd:(NAAdView *)adView;
@optional
- (void)adViewWillShowDummyAd:(NAAdView *)adView;
@optional
- (void)adViewWillClosedAd:(NAAdView *)adView;
@optional
- (void)adView:(NAAdView *)adView didFailRequestWithError:(NSError *)error;
@end

