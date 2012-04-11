//
//  RACConnectableSubscribable_Private.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/11/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACConnectableSubscribable.h"


@interface RACConnectableSubscribable ()

+ (RACConnectableSubscribable *)connectableSubscribableWithSourceSubscribable:(id<RACSubscribable>)source;

@end
