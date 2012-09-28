//
//  RACPropertySubscribableExamples.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/28/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

// The name of the shared examples for a subscribable-driven property.
extern NSString * const RACPropertySubscribableExamples;

// The block should have the signature:
//   void (^)(RACTestObject *testObject, NSString *keyPath, RACSubject *subject)
// and should tie the value of the key path on testObject to subject. The value
// for this key should not be nil.
extern NSString * const RACPropertySubscribableExamplesSetupBlock;
