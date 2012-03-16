//
//  RACBehaviorSubject.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/16/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACSubject.h"


@interface RACBehaviorSubject : RACSubject

+ (id)behaviorSubjectWithDefaultValue:(id)value;

@end
