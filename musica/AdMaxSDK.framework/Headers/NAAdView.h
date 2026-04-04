//
//  NAAdView.h
//  admaxsdk
//
//  Created by ninja on 2014/03/13.
//  Copyright (c) 2014年 samuraiFactory. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NAAdViewDelegate.h"

@interface NAAdView : UIView

extern NSInteger const NAAdViewDefaultWidth;
extern NSInteger const NAAdViewDefaultHeight;

@property (nonatomic, copy) IBInspectable NSString *adCode;
@property (nonatomic, assign) IBInspectable BOOL tracking;
@property (nonatomic, assign) IBInspectable BOOL testMode;
@property (nonatomic, weak) IBOutlet UIViewController *rootViewController;
@property (nonatomic, weak) IBOutlet id<NAAdViewDelegate> delegate;

- (id)initWithFrame:(CGRect)frame adCode:(NSString *)adCode;
- (id)initWithFrame:(CGRect)frame adCode:(NSString *)adCode tracking:(BOOL)tracking;
- (id)initWithFrame:(CGRect)frame adCode:(NSString *)adCode tracking:(BOOL)tracking testMode:(BOOL)testMode;

- (void)setWithAdCode:(NSString *)adCode tracking:(BOOL)tracking;
- (void)setWithAdCode:(NSString *)adCode tracking:(BOOL)tracking testMode:(BOOL)testMode;
- (void)setWithAdCode:(NSString *)adCode tracking:(BOOL)tracking testMode:(BOOL)testMode delegate:(id<NAAdViewDelegate>)delegate;

- (void)loadAd;
- (void)stopRequest;

@end
