//
//  RACChannel.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACDeprecated.h"
#import "RACSignal.h"
#import "RACSubscriber.h"

@class RACChannelTerminal;

RACDeprecated("Use two signals with -distinctUntilChanged or other feedback cancellation instead")
@interface RACChannel : NSObject

@property (nonatomic, strong, readonly) RACChannelTerminal *leadingTerminal;
@property (nonatomic, strong, readonly) RACChannelTerminal *followingTerminal;

@end

RACDeprecated("Use a signal and a subscriber instead")
@interface RACChannelTerminal : RACSignal <RACSubscriber>

- (id)init __attribute__((unavailable("Instantiate a RACChannel instead")));

@end
