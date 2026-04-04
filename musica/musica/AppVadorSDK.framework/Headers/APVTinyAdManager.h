//
//  APVTinyAdManager.h
//  AppVadorSDK
//
//  Created by Hirohide Sano on 2016/07/04
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "APVCommon.h"

@class APVTAdView, APVTAdConfiguration;
@protocol APVTinyAdManagerDelegate;
@interface APVTinyAdManager : NSObject

@property (nonatomic, weak) id<APVTinyAdManagerDelegate> delegate;
@property (nonatomic) APVPreloadType preloadType;
@property (nonatomic) BOOL isReady;
@property (nonatomic) APVTAdView *currentPlayer;
@property (nonatomic) APVTAdConfiguration *configuration;
@property (nonatomic, readonly) NSString *pubId;

- (id) initWithPubId:(NSString *) pubId withDelegate:(id<APVTinyAdManagerDelegate>) delegate;
- (id) initWithPubId:(NSString *) pubId withDelegate:(id<APVTinyAdManagerDelegate>) delegate withEnv: (APVEnv) env;
- (void) load;
- (void) load:(NSString *)vast;
- (void) reset;
- (UIView *) showAdForView:(UIView *)view;
- (UIView *) showAdForView:(UIView *)view withRect:(CGRect)rect;
- (void) removeAd;
- (BOOL)isFullScreen;

#pragma mark events
- (void) didClickThrough;
- (void) didClickToFullscreen;
- (void) didExitFullscreen;

#pragma mark player callbacks
- (void) didReadyToPlayAd;
- (void) didFailedToPlayAd:(NSObject *)error;

@end

#pragma mark -

@protocol APVTinyAdManagerDelegate <NSObject>

@required
- (UIViewController *)viewControllerForPresentingModalView;

@optional
- (void) onReadyToPlayAd:(APVTinyAdManager *)ad;
- (void) onReadyToPlayAd;
- (void) onFailedToPlayAd:(NSObject *)error;

@end