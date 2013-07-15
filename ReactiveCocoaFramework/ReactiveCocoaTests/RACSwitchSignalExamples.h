//
//  RACSwitchSignalExamples.h
//  ReactiveCocoa
//
//  Created by Robert Böhnke on 7/11/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

// The name of the sahred examples for `+switch:cases:` and
// `+switch:cases:default:`.
extern NSString * const RACSwitchSignalExamples;

// The block should have the signature:
//   RACSignal *(^)(RACSignal *keySignal, NSDictionary *cases)
// and return a new signal that uses the `keySignal` to switch over the cases
// in `cases`.
extern NSString * const RACSwitchSignalExamplesSetupBlock;
