//
//  RACMulticastConnection+Private.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/11/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACMulticastConnection.h"

@class RACSubject;

@interface RACMulticastConnection ()

- (id)initWithSourceSignal:(RACSignal *)source subject:(RACSubject *)subject;

@end
