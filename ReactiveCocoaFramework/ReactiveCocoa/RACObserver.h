//
//  RACObserver.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol RACObserver <NSObject>
- (void)sendNext:(id)value;
- (void)sendError:(NSError *)error;
- (void)sendCompleted;
@end


@interface RACObserver : NSObject <RACObserver>

// Creates a new observer with the given blocks.
+ (id)observerWithCompleted:(void (^)(void))completed error:(void (^)(NSError *error))error next:(void (^)(id x))next;

@end
