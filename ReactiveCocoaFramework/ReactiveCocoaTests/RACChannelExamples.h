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

// A block of type `RACChannelTerminal * (^)(void)`, which should create a new
// RACChannel to the test object and return an terminal.
extern NSString * const RACViewChannelExampleCreateTerminalBlock;

// The view being bound to in RACViewChannelExamples.
extern NSString * const RACViewChannelExampleView;

// The key path that will be read/written in RACViewChannelExamples. This
// must lead to an NSString property.
extern NSString * const RACViewChannelExampleKeyPath;
