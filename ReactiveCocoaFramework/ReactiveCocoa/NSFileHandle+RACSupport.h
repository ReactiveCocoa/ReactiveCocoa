//
//  NSFileHandle+RACSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/10/12.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSubscribable;


@interface NSFileHandle (RACSupport)

// Read any available data in the background and send it. Completes when data
// length is <= 0.
- (RACSubscribable *)rac_readInBackground;

@end
