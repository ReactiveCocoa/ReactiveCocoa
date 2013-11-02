//
//  NSString+RACSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/11/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSequence;
@class RACSignal;
@class RACScheduler;

@interface NSString (RACSupport)

/// Creates and returns a sequence containing strings corresponding to each
/// composed character sequence in the receiver.
///
/// Mutating the receiver will not affect the sequence after it's been created.
@property (nonatomic, copy, readonly) RACSequence *rac_sequence;

// Reads in the contents of the file using +[NSString stringWithContentsOfURL:usedEncoding:error:].
// Note that encoding won't be valid until the signal completes successfully.
//
// scheduler - cannot be nil.
+ (RACSignal *)rac_readContentsOfURL:(NSURL *)URL usedEncoding:(NSStringEncoding *)encoding scheduler:(RACScheduler *)scheduler;

@end
