//
//  RACCommand.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACDeprecated.h"

@class RACSignal;

extern NSString * const RACCommandErrorDomain;
extern const NSInteger RACCommandErrorNotEnabled;
extern NSString * const RACUnderlyingCommandErrorKey;

RACDeprecated("Use RACAction instead")
@interface RACCommand : NSObject

@property (nonatomic, strong, readonly) RACSignal *executionSignals;
@property (atomic, assign) BOOL allowsConcurrentExecution;

@property (nonatomic, strong, readonly) RACSignal *executing;
@property (nonatomic, strong, readonly) RACSignal *enabled;
@property (nonatomic, strong, readonly) RACSignal *errors;

- (id)initWithSignalBlock:(RACSignal * (^)(id input))signalBlock RACDeprecated("Use +[RACDynamicSignalGenerator generatorWithBlock:] and RACAction instead");
- (id)initWithEnabled:(RACSignal *)enabledSignal signalBlock:(RACSignal * (^)(id input))signalBlock RACDeprecated("Use +[RACDynamicSignalGenerator generatorWithBlock:] and RACAction instead");

- (RACSignal *)execute:(id)input;

@end

@interface RACCommand (Unavailable)

@property (atomic, readonly) BOOL canExecute __attribute__((unavailable));

+ (instancetype)command __attribute__((unavailable));
+ (instancetype)commandWithCanExecuteSignal:(RACSignal *)canExecuteSignal __attribute__((unavailable));
- (id)initWithCanExecuteSignal:(RACSignal *)canExecuteSignal __attribute__((unavailable));
- (RACSignal *)addSignalBlock:(RACSignal * (^)(id value))signalBlock __attribute__((unavailable));

@end
