//
//  NSSet+RACSupport.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACCollection.h"
#import "RACDeprecated.h"

@class RACSequence;
@class RACSignal;

@interface NSSet (RACSupport)

/// A signal that will send all of the objects in the collection.
///
/// Mutating the collection will not affect the signal after it's been created.
@property (nonatomic, strong, readonly) RACSignal *rac_signal;

@end

@interface NSMutableSet (RACCollectionSupport) <RACCollection>
@end

@interface NSSet (RACSupportDeprecated)

@property (nonatomic, copy, readonly) RACSequence *rac_sequence RACDeprecated("Use -rac_signal instead");

@end
