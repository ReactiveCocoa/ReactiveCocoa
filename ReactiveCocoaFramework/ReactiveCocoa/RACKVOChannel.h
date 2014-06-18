//
//  RACKVOChannel.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 27/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACChannel.h"
#import "RACDeprecated.h"

#import "EXTKeyPathCoding.h"
#import "metamacros.h"

#define RACChannelTo(TARGET, ...) \
    metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__)) \
        (RACChannelTo_(TARGET, __VA_ARGS__, nil)) \
        (RACChannelTo_(TARGET, __VA_ARGS__))

#define RACChannelTo_(TARGET, KEYPATH, NILVALUE) \
    [[RACKVOChannel alloc] initWithTarget:(TARGET) keyPath:@keypath(TARGET, KEYPATH) nilValue:(NILVALUE)][@keypath(RACKVOChannel.new, followingTerminal)]

RACDeprecated("Use two signals with -distinctUntilChanged or other feedback cancellation instead")
@interface RACKVOChannel :
	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	RACChannel
	#pragma clang diagnostic pop

- (id)initWithTarget:(NSObject *)target keyPath:(NSString *)keyPath nilValue:(id)nilValue;

- (id)init __attribute__((unavailable("Use -initWithTarget:keyPath:nilValue: instead")));

@end

@interface RACKVOChannel (RACChannelTo)

- (RACChannelTerminal *)objectForKeyedSubscript:(NSString *)key RACDeprecated("Use RACObserve() instead");
- (void)setObject:(RACChannelTerminal *)otherTerminal forKeyedSubscript:(NSString *)key RACDeprecated("Use RAC() instead");

@end
