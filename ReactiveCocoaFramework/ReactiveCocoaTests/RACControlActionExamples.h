//
//  RACControlActionExamples.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-08-15.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

// The name of the shared examples for any control class that has
// `rac_action` and `isEnabled` properties.
extern NSString * const RACControlActionExamples;

// The control to test.
extern NSString * const RACControlActionExampleControl;

// A block of type `void (^)(id control)` which should activate the
// `rac_action` of the `control` by manipulating the control itself.
extern NSString * const RACControlActionExampleActivateBlock;
