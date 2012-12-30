//
//  RACLazyProperty.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 30/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <ReactiveCocoa/ReactiveCocoa.h>

// A property with a lazily generated default value.
@interface RACLazyProperty : RACProperty

// Creates a new lazy property. The property's default value is the first value
// sent by `start`. `start` must send at least one value.
+ (instancetype)lazyPropertyWithStart:(RACSignal *)start;

@end
