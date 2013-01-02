//
//  RACPropertyExamples.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 30/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

// The name of the shared examples for RACProperty and it's subclasses. This
// example should be passed the following arguments:
//
// getProperty  - A block of type `RACProperty (^)(void)`, which should return a
//                new RACProperty.
extern NSString * const RACPropertyExamples;

// The name of the shared memory management examples for RACProperty and it's
// subclasses (except RACKVOProperty, since it has different memory management
// semantics). This example should be passed the following arguments:
//
// getProperty  - A block of type `RACProperty (^)(void)`, which should return a
//                new RACProperty.
extern NSString * const RACPropertyMemoryManagementExamples;
