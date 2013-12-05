//
//  NSFileHandle+RACSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/10/12.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACDeprecated.h"

@class RACPromise;
@class RACSignal;

@interface NSFileHandle (RACSupport)

// Reads the file handle in the background until end-of-file is reached.
//
// Starting this promise will replace the receiver's `readabilityHandler` with
// a custom block. The block property must not be touched until this promise
// terminates.
@property (nonatomic, strong, readonly) RACPromise *rac_availableData;

@end

@interface NSFileHandle (RACSupportDeprecated)

- (RACSignal *)rac_readInBackground RACDeprecated("Use -rac_availableData instead");

@end
