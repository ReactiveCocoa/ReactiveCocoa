//
//  RACProxy.h
//  ReactiveCocoa
//
//  Created by Avi Itskovich on 2/21/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <ReactiveCocoa/ReactiveCocoa.h>

// Represents a lazy a object.
//
// This class represents an object that is generated lazily when it
// is needed. Specifically, on the first selector called on it, the
// object is generated from the passed in block.
@interface RACProxy : NSObject

+ (id)return:(id (^)(void))block;

@end
