//
//  RACMaybe.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/8/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


// Represents the return value of a method that could be either an object or an
// error.
@interface RACMaybe : NSObject

@property (nonatomic, readonly, strong) id object;
@property (nonatomic, readonly, strong) NSError *error;

+ (id)maybeWithObject:(id)object;
+ (id)maybeWithError:(NSError *)error;

- (BOOL)hasObject;
- (BOOL)hasError;

@end
