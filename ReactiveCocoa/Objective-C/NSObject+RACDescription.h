//
//  NSObject+RACDescription.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-05-13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

// A private category providing a terser but faster alternative to -description.
@interface NSObject (RACDescription)

// A simplified description of the receiver, which does not invoke -description
// (and thus should be much faster in many cases).
//
// This is for debugging purposes only, and will return a constant string
// unless the RAC_DEBUG_SIGNAL_NAMES environment variable is set.
- (NSString *)rac_description;

@end
