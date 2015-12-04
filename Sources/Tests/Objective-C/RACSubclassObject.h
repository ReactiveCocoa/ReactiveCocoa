//
//  RACSubclassObject.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/18/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACTestObject.h"

@interface RACSubclassObject : RACTestObject

// Set whenever -forwardInvocation: is invoked on the receiver.
@property (nonatomic, assign) SEL forwardedSelector;

// Invokes the superclass implementation with `objectValue` concatenated to
// "SUBCLASS".
- (NSString *)combineObjectValue:(id)objectValue andIntegerValue:(NSInteger)integerValue;

// Asynchronously invokes the superclass implementation on the current scheduler.
- (void)setObjectValue:(id)objectValue andSecondObjectValue:(id)secondObjectValue;

@end
