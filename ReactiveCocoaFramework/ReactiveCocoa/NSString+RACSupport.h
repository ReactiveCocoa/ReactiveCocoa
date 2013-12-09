//
//  NSString+RACSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/11/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACDeprecated.h"

@class RACSequence;
@class RACSignal;
@class RACScheduler;

@interface NSString (RACSupport)

/// A signal that will send NSStrings corresponding to each composed character
/// sequence in the receiver.
///
/// Mutating the string will not affect the signal after it's been created.
@property (nonatomic, strong, readonly) RACSignal *rac_signal;

// Reads in the contents of the given URL using +[NSString
// stringWithContentsOfURL:usedEncoding:error:].
//
// Returns a signal which will send a tuple containing the `NSString` of the
// URL's content, and an `NSNumber`-boxed `NSStringEncoding` indicating the
// encoding used to read it, then complete.
+ (RACSignal *)rac_contentsAndEncodingOfURL:(NSURL *)URL;

@end

@interface NSString (RACSupportDeprecated)

@property (nonatomic, copy, readonly) RACSequence *rac_sequence RACDeprecated("Use -rac_signal instead");

+ (RACSignal *)rac_readContentsOfURL:(NSURL *)URL usedEncoding:(NSStringEncoding *)encoding scheduler:(RACScheduler *)scheduler RACDeprecated("Use +rac_contentsAndEncodingOfURL: instead");

@end
