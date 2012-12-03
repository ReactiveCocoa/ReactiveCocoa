//
//  NSObject+RACCocoaTouchBindings.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 03/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (RACCocoaTouchBindings)

// Create a two-way binding between `receiverKeyPath` on the receiver and
// `otherKeyPath` on `otherObject`.
//
// `receiverKeyPath` on the receiver will be updated with the value of
// `otherKeyPath` on `otherObject`. After that, the two properties will be kept
// in sync by forwarding changes to one onto the other.
//
// Returns a disposable that can be used to sever the binding.
- (RACDisposable *)rac_bind:(NSString *)receiverKeyPath toObject:(id)otherObject withKeyPath:(NSString *)otherKeyPath;

@end
