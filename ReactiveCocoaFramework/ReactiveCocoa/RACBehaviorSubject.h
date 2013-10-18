//
//  RACBehaviorSubject.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACDeprecated.h"
#import "RACSubject.h"

RACDeprecated("Use a plain RACSignal or -[RACSignal promise] instead")
@interface RACBehaviorSubject : RACSubject

+ (instancetype)behaviorSubjectWithDefaultValue:(id)value;

@end
