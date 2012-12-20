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
//   void (^)(RACTestObject *testObject, NSString *keyPath, RACSignal *signal)
// and should tie the value of the key path on testObject to signal. The value
// for this key should not be nil.
extern NSString * const RACPropertySignalExamplesSetupBlock;
