//
//  RACCollection.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/// An abstraction of a collection, which may or may not be ordered.
@protocol RACCollection <NSObject>
@required

/// Inserts the given objects into the receiver.
///
/// The order of the given array is not guaranteed to be preserved.
- (void)rac_addObjects:(NSArray *)objects;

/// Removes the given objects from the receiver.
- (void)rac_removeObjects:(NSArray *)objects;

/// Replaces the contents of the receiver with that of the given array.
///
/// The order of the array is not guaranteed to be preserved.
- (void)rac_replaceAllObjects:(NSArray *)objects;

@end
