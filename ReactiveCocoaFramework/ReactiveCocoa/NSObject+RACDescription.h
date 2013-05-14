//
//  NSObject+RACDescription.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-05-13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (RACDescription)

// Returns a simplified description of the receiver, which does not invoke
// -description (and thus should be much faster in many cases).
- (NSString *)rac_description;

@end
