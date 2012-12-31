//
//  RACProperty+Private.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 31/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACProperty.h"
@class RACSignal;
@protocol RACSubscriber;

@interface RACProperty ()

// Designated initializer. `signal` and `subscriber`'s values are `RACTuple`s of
// two elements where the first element is the value being sent to / by the
// property, and the second element is the binding that sent the value to the
// property, or nil if the value wasn't sent by a binding.
- (instancetype)initWithSignal:(RACSignal *)signal subscriber:(id<RACSubscriber>)subscriber;

@end

@interface RACBinding ()

@end
