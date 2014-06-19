//
//  RACSubject.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/9/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACDeprecated.h"
#import "RACSignal.h"
#import "RACSubscriber.h"

RACDeprecated("Instantiate a RACSubscriber instead")
@interface RACSubject : RACSignal <RACSubscriber>

+ (instancetype)subject;

@end
