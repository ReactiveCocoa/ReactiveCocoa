//
//  NSArray+RACStream.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 11/10/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSArray+RACStream.h"

@implementation NSArray (RACStream)

+ (instancetype)empty {
  return @[];
}

+ (instancetype)return:(id)value {
  return @[ value ];
}

- (instancetype)bind:(id (^)(id, BOOL *))block {
  NSMutableArray *mapped = NSMutableArray.array;
  BOOL stop = NO;
  
  for (id value in self) {
    NSArray *result = block(value, &stop);
    if (!result) {
      break;
    }
    
		NSAssert([result isKindOfClass:NSArray.class], @"-bind: block returned an object that is not an array: %@", result);
    
    [mapped addObject:result];
    if (stop) {
      break;
    }
  }
  
  NSMutableArray *flattened = [NSMutableArray array];
  for (NSArray *value in mapped) {
    [flattened addObjectsFromArray:value];
  }
  return flattened.copy;
}

- (instancetype)concat:(id<RACStream>)stream {
  return [self arrayByAddingObjectsFromArray:(NSArray *)stream];
}

@end
