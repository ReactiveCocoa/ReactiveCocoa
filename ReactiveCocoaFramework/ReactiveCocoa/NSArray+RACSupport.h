//
//  NSArray+RACSupport.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACDeprecated.h"
#import "RACOrderedCollection.h"

@class RACSequence;
@class RACSignal;

@interface NSArray (RACSupport)

/// A signal that will send all of the objects in the collection.
///
/// Mutating the collection will not affect the signal after it's been created.
@property (nonatomic, strong, readonly) RACSignal *rac_signal;

@end

@interface NSMutableArray (RACCollectionSupport) <RACOrderedCollection>
@end

@interface NSArray (RACSupportDeprecated)

@property (nonatomic, copy, readonly) RACSequence *rac_sequence RACDeprecated("Use -rac_signal instead");

@end
