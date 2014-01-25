//
//  RACBehaviorSubject.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACDeprecated.h"
#import "RACSubject.h"

RACDeprecated("Bind to a property with RAC() and give it a default value instead")
@interface RACBehaviorSubject : RACSubject

+ (instancetype)behaviorSubjectWithDefaultValue:(id)value;

@end
