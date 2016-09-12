//
//  RACValueTransformer.h
//  ReactiveObjC
//
//  Created by Josh Abernathy on 3/6/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

// A private block based transformer.
@interface RACValueTransformer : NSValueTransformer

+ (instancetype)transformerWithBlock:(id (^)(id value))block;

@end
