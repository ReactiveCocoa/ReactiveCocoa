//
//  NSString+RACKeyPathUtilities.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 05/05/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (RACKeyPathUtilities)

// Returns an array of the components of the receiver, or nil if the receiver is
// not a valid key path.
- (NSArray *)rac_keyPathComponents;

// Returns a key path with all the components of the receiver except for the
// last one or nil if the receiver is not a valid key path, or has only one
// component.
- (NSString *)rac_keyPathByDeletingLastKeyPathComponent;

@end
