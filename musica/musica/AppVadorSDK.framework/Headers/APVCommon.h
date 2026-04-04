//
//  APVCommon.h
//  AppVadorSDK
//
//  Created by Hirohide SANO on 2016/07/04.
//
//

typedef enum : NSInteger {
    APV_ENV_PRODUCTION,
    APV_ENV_TEST,
    APV_ENV_DEVELOPMENT
} APVEnv;

typedef enum : NSInteger {
    APV_PRELOAD_META,
    APV_PRELOAD_ALL
} APVPreloadType;