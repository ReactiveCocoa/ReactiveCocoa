//
//  NSString+RACKeyPathUtilities.h
//  ReactiveObjC
//
//  Created by Uri Baghin on 05/05/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

// A private category of methods to extract parts of a key path.
@interface NSString (RACKeyPathUtilities)

// Returns an array of the components of the receiver.
//
// Calling this method on a string that isn't a key path is considered undefined
// behavior.
- (NSArray *)rac_keyPathComponents;

// Returns a key path with all the components of the receiver except for the
// last one.
//
// Calling this method on a string that isn't a key path is considered undefined
// behavior.
- (NSString *)rac_keyPathByDeletingLastKeyPathComponent;

// Returns a key path with all the components of the receiver expect for the
// first one.
//
// Calling this method on a string that isn't a key path is considered undefined
// behavior.
- (NSString *)rac_keyPathByDeletingFirstKeyPathComponent;

@end
