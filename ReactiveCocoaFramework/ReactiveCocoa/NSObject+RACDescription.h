//
//  NSObject+RACDescription.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-05-13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (RACDescription)

/// A simplified description of the receiver for Debug builds, which does not
/// invoke -description (and thus should be much faster in many cases).
///
/// This method will return a constant string in Release builds, skipping any
/// work.
- (NSString *)rac_description;

@end
