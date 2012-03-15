//
//  RACSubject.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/9/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACObservable.h"
#import "RACObserver.h"


@interface RACSubject : RACObservable <RACObserver>

+ (id)subject;

@end
