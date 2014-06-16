//
//  NSData+RACSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/11/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACDeprecated.h"

@class RACScheduler;
@class RACSignal;

@interface NSData (RACSupport)

// Read the data at the given URL using -[NSData
// initWithContentsOfURL:options:error:].
//
// Returns a signal which will send the read `NSData` then complete, or error.
+ (RACSignal *)rac_contentsOfURL:(NSURL *)URL options:(NSDataReadingOptions)options;

@end

@interface NSData (RACSupportDeprecated)

+ (RACSignal *)rac_readContentsOfURL:(NSURL *)URL options:(NSDataReadingOptions)options scheduler:(RACScheduler *)scheduler RACDeprecated("Use +rac_contentsOfURL:options: instead");

@end
