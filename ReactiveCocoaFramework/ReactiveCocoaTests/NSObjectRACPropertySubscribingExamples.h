//
//  NSObjectRACPropertySubscribingExamples.h
//  ReactiveCocoa
//
//  Created by Josh Vera on 4/10/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

// The name of the shared examples for a signal-driven observation.
extern NSString * const RACPropertySubscribingExamples;

// The block should have the signature:
//   RACSignal * (^)(RACTestObject *testObject, NSString *keyPath, id observer)
// and should observe the value of the key path on testObject with observer. The value
// for this key should not be nil.
extern NSString * const RACPropertySubscribingExamplesSetupBlock;
