//
//  RACBindingExamples.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 30/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

// The name of the shared examples for RACBinding and its subclasses.
extern NSString * const RACBindingExamples;

// A block of type `RACBinding * (^)(void)`, which should return a new
// RACBinding.
extern NSString * const RACBindingExampleCreateBlock;

// The name of the shared examples for any RACBinding class that gets and sets
// a property.
extern NSString * const RACViewBindingExamples;

// A block of type `RACBindingTerminal * (^)(void)`, which should create a new
// RACBinding to the test object and return an terminal.
extern NSString * const RACViewBindingExampleCreateTerminalBlock;

// The view being bound to in RACViewBindingExamples.
extern NSString * const RACViewBindingExampleView;

// The key path that will be read/written in RACViewBindingExamples. This
// must lead to an NSString property.
extern NSString * const RACViewBindingExampleKeyPath;
