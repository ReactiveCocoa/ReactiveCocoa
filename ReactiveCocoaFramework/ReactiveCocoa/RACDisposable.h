//
//  RACDisposable.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/16/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface RACDisposable : NSObject

+ (id)disposableWithBlock:(void (^)(void))block;

- (void)dispose;

@end
