//
//  NSObject+RACDescription.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-05-13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (RACDescription)

/// A simplified description of the receiver, which does not invoke -description
/// (and thus should be much faster in many cases).
///
/// This is for debugging purposes only, and will return a constant string
/// unless the RAC_DEBUG_SIGNAL_NAMES environment variable is set.
- (NSString *)rac_description;

/// Returns a block that returns the receiver's description or its class name.
///
/// The returned block references the receiver weakly, and will return only the
/// class name if the receiver was deallocated.
- (NSString *(^)())rac_deferredDescription;

@end
