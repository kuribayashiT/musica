//
//  AVAudioSession+Swift.h
//  musica
//
//  Created by 栗林貴大 on 2018/11/17.
//  Copyright © 2018 K.T. All rights reserved.
//

#ifndef AVAudioSession_Swift_h
#define AVAudioSession_Swift_h

@import AVFoundation;

NS_ASSUME_NONNULL_BEGIN

@interface AVAudioSession (Swift)

- (BOOL)swift_setCategory:(AVAudioSessionCategory)category error:(NSError **)outError NS_SWIFT_NAME(setCategory(_:));

@end

NS_ASSUME_NONNULL_END
#endif /* AVAudioSession_Swift_h */
