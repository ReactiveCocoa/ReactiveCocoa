//
//  RACAction.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-11.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const RACActionErrorDomain;
extern const NSInteger RACActionErrorNotEnabled;
extern NSString * const RACActionErrorKey;

@class RACSignal;
@class RACSignalGenerator;

@interface RACAction : NSObject

@property (nonatomic, strong, readonly) RACSignal *enabled;
@property (nonatomic, strong, readonly) RACSignal *executing;
@property (nonatomic, strong, readonly) RACSignal *errors;

+ (instancetype)actionWithEnabled:(RACSignal *)enabledSignal generator:(RACSignalGenerator *)generator;
+ (instancetype)actionWithGenerator:(RACSignalGenerator *)generator;

+ (instancetype)actionWithEnabled:(RACSignal *)enabledSignal signal:(RACSignal *)signal;
+ (instancetype)actionWithSignal:(RACSignal *)signal;

- (void)execute:(id)input;
- (RACSignal *)deferred:(id)input;

@end
