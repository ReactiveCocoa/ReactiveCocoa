//
//  NSFileHandle+RACSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/10/12.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACDeprecated.h"

@class RACSignal;

@interface NSFileHandle (RACSupport)

/// Repeatedly reads any available data in the background.
///
/// Returns a signal that will send zero or more `NSData` objects, then complete
/// when no more data can be read.
- (RACSignal *)rac_readDataToEndOfFile;

@end

@interface NSFileHandle (RACSupportDeprecated)

// Read any available data in the background and send it. Completes when data
// length is <= 0.
- (RACSignal *)rac_readInBackground RACDeprecated("Use -rac_readDataToEndOfFile instead");

@end
