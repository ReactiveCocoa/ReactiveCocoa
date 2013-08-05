//
//  RACChannelExamples.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 30/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

// The name of the shared examples for RACChannel and its subclasses.
extern NSString * const RACChannelExamples;

// A block of type `RACChannel * (^)(void)`, which should return a new
// RACChannel.
extern NSString * const RACChannelExampleCreateBlock;

// The name of the shared examples for any RACChannel class that gets and sets
// a property.
extern NSString * const RACViewChannelExamples;

// A block of type `NSObject * (^)(void)`, which should create a new test view
// and return it.
extern NSString * const RACViewChannelExampleCreateViewBlock;

// A block of type `RACChannelTerminal * (^)(NSObject *view)`, which should
// create a new RACChannel to the given test view and return an terminal.
extern NSString * const RACViewChannelExampleCreateTerminalBlock;

// The key path that will be read/written in RACViewChannelExamples. This
// must lead to an NSString property.
extern NSString * const RACViewChannelExampleKeyPath;

// A block of type `void (^)(NSObject *view, NSString *text)`, which should
// change the given test view's text to the given string.
extern NSString * const RACViewChannelExampleSetViewTextBlock;
