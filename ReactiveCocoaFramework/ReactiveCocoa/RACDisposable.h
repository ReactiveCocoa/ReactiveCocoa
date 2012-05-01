//
//  RACDisposable.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACScopedDisposable;


// A disposable encapsulates the work necessary to tear down and cleanup a
// subscription.
@interface RACDisposable : NSObject

+ (id)disposableWithBlock:(void (^)(void))block;

// Performs the disposal work. Can be called multiple times, though sebsequent
// calls won't do anything.
- (void)dispose;

// Returns a new disposable which will dispose of this disposable when it gets
// dealloc'd.
- (RACScopedDisposable *)asScopedDisposable;

@end
