//
//  FiveAd.h
//  FiveAd
//
//  Created by Yusuke Konishi on 2014/11/12.
//  Copyright (c) 2014年 Five. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class WKUserContentController;

/******************************************************************************
 * What we defined on this header.
 ******************************************************************************/
@protocol FADAdInterface;
@protocol FADDelegate;

@class FADConfig;
@class FADSettings;
@class FADInterstitial;
@class FADInFeed;
@class FADBounce;
@class FADAdViewW320H180;

@protocol FADContentInterface;
@protocol FADContentDelegate;
@class FADContentView;

typedef enum: NSInteger {
  kFADErrorNone = 0,
  kFADErrorNetworkError = 1,
  kFADErrorNoCachedAd = 2,
  kFADErrorNoFill = 3,
  kFADErrorBadAppId = 4,
  kFADErrorStorageError = 5,
  kFADErrorInternalError = 6,
  kFADErrorUnsupportedOsVersion = 7,
  kFADErrorInvalidState = 8,
  kFADErrorBadSlotId = 9,
  kFADErrorSuppressed = 10,
  kFADErrorContentUnavailable = 11,
  kFADErrorPlayerError = 12
} FADErrorCode;

typedef enum: NSInteger {
  kFADFormatInterstitialLandscape = 1, // until ver.20180420
  kFADFormatInterstitialPortrait = 2,  // until ver.20180420
  kFADFormatInFeed = 3,
  kFADFormatBounce = 4,
  kFADFormatW320H180 = 5,
  kFADFormatW300H250 = 6,
  kFADFormatCustomLayout = 7,
  kFADFormatVideoReward = 8            // use this for interstitial too since ver.20180601
} FADFormat;

typedef enum: NSInteger {
  kFADStateNotLoaded = 1,
  kFADStateLoading = 2,
  kFADStateLoaded = 3,
  kFADStateShowing = 4,
  kFADStateClosed = 5,
  kFADStateError = 6
} FADState;

/******************************************************************************
 * FADConfig
 ******************************************************************************/
@interface FADConfig : NSObject
- (id)initWithAppId:(NSString *)appId;

@property (nonatomic,readonly) NSString *appId;
@property (nonatomic) NSSet *fiveAdFormat;
@property (nonatomic) BOOL isTest; // NO by default.
@end

/******************************************************************************
 * FADSettings
 ******************************************************************************/
@interface FADSettings : NSObject
- (id)init __attribute__((unavailable("init is not available. use sharedInstanceWithConfig.")));

// Please call this method first.
// Calling this method multiple times with same configuration is valid.
+ (void)registerConfig:(FADConfig *)config;

// Once registerConfig is called with valid config argument, this returns true.
+ (BOOL)isConfigRegistered;

// disabled by default. please call enableLoading:YES after registerConfig.
+ (void)enableLoading:(BOOL)enabled;
+ (BOOL)isLoadingEnabled;

// enabled by default.
+ (void)enableSound:(BOOL)enabled;
+ (BOOL)isSoundEnabled;

+ (NSString *)version;

// setup WKUserContentController to show web page ads within WKWebView.
+ (void)setupFADWKWebViewHelperScript:(WKUserContentController *)controller;

@end

/******************************************************************************
 * Ad Objects.
 ******************************************************************************/
@protocol FADAdInterface <NSObject>
- (void)loadAd;

// default value is FADSettings's isSoundEnabled.
- (void)enableSound:(BOOL)enabled;
- (BOOL)isSoundEnabled;

@property (nonatomic, weak) id<FADDelegate> delegate;
@property (nonatomic, readonly) NSString *slotId;
@property (nonatomic, readonly) FADState state;

// PLEASE DON'T USE FOLLOWING METHODS until Five's dev-rel specified to do so...
- (NSString *)getAdParameter;
@end

@interface FADInterstitial: NSObject<FADAdInterface>
- (id)initWithSlotId:(NSString *)slotId;
- (BOOL)show;
@end

@interface FADAdViewW320H180: UIView<FADAdInterface>
- (id)initWithFrame:(CGRect)frame slotId:(NSString *)slotId;

// Only available after ad is loaded.
// This may returns empty string e.g. @""
- (NSString *)getAdvertiserName;

@end

@interface FADBounce: NSObject<FADAdInterface>
- (id)initWithSlotId:(NSString *)slotId scrollView:(UIScrollView *)scrollView;
- (id)initWithSlotId:(NSString *)slotId scrollView:(UIScrollView *)scrollView offsetY:(float)offsetY;
- (id)initWithSlotId:(NSString *)slotId scrollView:(UIScrollView *)scrollView offsetY:(float)offsetY contentsHeight:(float)contentsHeight;
@end

@interface FADInFeed: UIView<FADAdInterface>
// height will changed when loadAd is completed.
- (id)initWithSlotId:(NSString *)slotId width:(float)width;
@end

@interface FADAdViewCustomLayout: UIView<FADAdInterface>
- (id)initWithSlotId:(NSString *)slotId width:(float)width;

// Only available after ad is loaded.
// This may returns empty string e.g. @""
- (NSString *)getAdvertiserName;
@end

// PLEASE DON'T USE FOLLOWING FEATURE unless Five's dev-rel specified to do so...
@interface FADVideoReward: NSObject<FADAdInterface>
- (id)initWithSlotId:(NSString *)slotId;
- (BOOL)show;
@end


/******************************************************************************
 * FADDelegate
 ******************************************************************************/
@protocol FADDelegate <NSObject>
- (void)fiveAdDidLoad:(id<FADAdInterface>)ad;
- (void)fiveAd:(id<FADAdInterface>)ad didFailedToReceiveAdWithError:(FADErrorCode) errorCode;
- (void)fiveAdDidClick:(id<FADAdInterface>)ad;
- (void)fiveAdDidClose:(id<FADAdInterface>)ad;
- (void)fiveAdDidStart:(id<FADAdInterface>)ad;
- (void)fiveAdDidPause:(id<FADAdInterface>)ad;
- (void)fiveAdDidResume:(id<FADAdInterface>)ad;
- (void)fiveAdDidViewThrough:(id<FADAdInterface>)ad;
- (void)fiveAdDidReplay:(id<FADAdInterface>)ad;
@end


#pragma mark *** Five Content Delivery ***
// PLEASE DON'T USE Content Delivery until Five's dev-rel specified to do so...

/******************************************************************************
 * FADContent
 ******************************************************************************/
@protocol FADContentInterface <NSObject>
- (void)loadContentAsync;

// default value is FADSettings's isSoundEnabled.
- (void)enableSound:(BOOL)enabled;
- (BOOL)isSoundEnabled;
- (void)enterFullscreenAndShowForm;

@property (nonatomic, weak) id<FADContentDelegate> delegate;
@property (nonatomic, readonly) NSString *contentId;
@property (nonatomic, readonly) FADState state;
@end

@interface FADContentView: UIView<FADContentInterface>
- (id)initWithFrame:(CGRect)frame contentId:(NSString *)contentId;
@end

/******************************************************************************
 * FADContentDelegate
 ******************************************************************************/
@protocol FADContentDelegate <NSObject>
- (void)fiveContentDidLoad:(id<FADContentInterface>)content;
- (void)fiveContentDidReady:(id<FADContentInterface>)content;
- (void)fiveContent:(id<FADContentInterface>)content didFailedToReceiveContentWithError:(FADErrorCode) errorCode;
- (void)fiveContentDidClick:(id<FADContentInterface>)content;
- (void)fiveContentDidClose:(id<FADContentInterface>)content;
- (void)fiveContentDidStart:(id<FADContentInterface>)content;
- (void)fiveContentDidPause:(id<FADContentInterface>)content;
- (void)fiveContentDidResume:(id<FADContentInterface>)content;
- (void)fiveContentDidViewThrough:(id<FADContentInterface>)content;
- (void)fiveContentDidReplay:(id<FADContentInterface>)content;
- (void)fiveContentDidStall:(id<FADContentInterface>)content;
- (void)fiveContentDidRecover:(id<FADContentInterface>)content;
@end
