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

@property (nonatomic, strong, readonly) RACSignal *executing RACDeprecated("Use RACAction.executing instead");
@property (nonatomic, strong, readonly) RACSignal *enabled RACDeprecated("Use a separate 'enabled' signal instead");
@property (nonatomic, strong, readonly) RACSignal *errors RACDeprecated("Use RACAction.errors instead");

- (id)initWithSignalBlock:(RACSignal * (^)(id input))signalBlock RACDeprecated("Use -[RACSignal action] instead");
- (id)initWithEnabled:(RACSignal *)enabledSignal signalBlock:(RACSignal * (^)(id input))signalBlock RACDeprecated("Use -[RACSignal action] and a separate 'enabled' signal instead");

- (RACSignal *)execute:(id)input RACDeprecated("Use -[RACAction execute:] or -[RACAction deferred] instead");

@end

@interface RACCommand (Unavailable)

@property (atomic, readonly) BOOL canExecute __attribute__((unavailable("Use the 'enabled' signal instead")));

+ (instancetype)command __attribute__((unavailable("Use -initWithSignalBlock: instead")));
+ (instancetype)commandWithCanExecuteSignal:(RACSignal *)canExecuteSignal __attribute__((unavailable("Use -initWithEnabled:signalBlock: instead")));
- (id)initWithCanExecuteSignal:(RACSignal *)canExecuteSignal __attribute__((unavailable("Use -initWithEnabled:signalBlock: instead")));
- (RACSignal *)addSignalBlock:(RACSignal * (^)(id value))signalBlock __attribute__((unavailable("Pass the signalBlock to -initWithSignalBlock: instead")));

@end
