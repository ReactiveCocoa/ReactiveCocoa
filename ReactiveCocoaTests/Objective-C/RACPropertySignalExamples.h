//
//  RACPropertySignalExamples.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/28/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

// The name of the shared examples for a signal-driven property.
extern NSString * const RACPropertySignalExamples;

// The block should have the signature:
//
//   void (^)(RACTestObject *testObject, NSString *keyPath, id nilValue, RACSignal *signal)
//
// and should tie the value of the key path on testObject to signal. `nilValue`
// will be used when the signal sends a `nil` value.
extern NSString * const RACPropertySignalExamplesSetupBlock;
