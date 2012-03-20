//
//  RACSubject.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/9/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACSubscribable.h"
#import "RACSubscriber.h"


@interface RACSubject : RACSubscribable <RACSubscriber>

+ (id)subject;

@end
