//
//  RACAction.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-11.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACSignal.h"
#import "RACSignalGenerator.h"

extern NSString * const RACActionErrorDomain;
extern const NSInteger RACActionErrorNotEnabled;
extern NSString * const RACActionErrorKey;

@interface RACAction : NSObject

@property (nonatomic, strong, readonly) RACSignal *enabled;
@property (nonatomic, strong, readonly) RACSignal *executing;
@property (nonatomic, strong, readonly) RACSignal *errors;

- (void)execute:(id)input;
- (RACSignal *)deferred:(id)input;

@end

@interface RACSignalGenerator (RACActionAdditions)

- (RACAction *)action;
- (RACAction *)actionEnabledIf:(RACSignal *)enabledSignal;

@end

@interface RACSignal (RACActionAdditions)

- (RACAction *)action;
- (RACAction *)actionEnabledIf:(RACSignal *)enabledSignal;

@end
