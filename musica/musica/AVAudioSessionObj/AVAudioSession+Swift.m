//
//  AVAudioSession+Swift.m
//  musica
//
//  Created by 栗林貴大 on 2018/11/17.
//  Copyright © 2018 K.T. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVAudioSession+Swift.h"
@implementation AVAudioSession (Swift)

- (BOOL)swift_setCategory:(AVAudioSessionCategory)category error:(NSError **)outError {
    return [self setCategory:category error:outError];
}

@end
