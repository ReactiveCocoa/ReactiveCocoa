//
//  RACCommand+Private.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/7/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

@interface RACCommand ()
@property (nonatomic, copy) BOOL (^canExecuteBlock)(id value);
@property (nonatomic, copy) void (^executeBlock)(id value);
@end
