//
//  RACValueTransformer.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface RACValueTransformer : NSValueTransformer

+ (RACValueTransformer *)transformerWithBlock:(id (^)(id value))block;

@end
