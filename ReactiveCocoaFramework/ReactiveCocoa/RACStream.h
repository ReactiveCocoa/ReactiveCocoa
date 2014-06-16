//
//  RACStream.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-31.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACDeprecated.h"

@class RACStream;

typedef RACStream * (^RACStreamBindBlock)(id value, BOOL *stop);

RACDeprecated("Use RACSignal instead")
@interface RACStream : NSObject

@property (copy) NSString *name;

- (instancetype)setNameWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);

+ (instancetype)empty;
+ (instancetype)return:(id)value;

- (instancetype)bind:(RACStreamBindBlock (^)(void))block;
- (instancetype)concat:(RACStream *)stream;
- (instancetype)zipWith:(RACStream *)stream;

- (instancetype)flattenMap:(RACStream * (^)(id value))block;
- (instancetype)flatten;
- (instancetype)map:(id (^)(id value))block;
- (instancetype)mapReplace:(id)object;
- (instancetype)filter:(BOOL (^)(id value))block;
- (instancetype)ignore:(id)value;
- (instancetype)reduceEach:(id (^)())reduceBlock;
- (instancetype)startWith:(id)value;
- (instancetype)skip:(NSUInteger)skipCount;
- (instancetype)take:(NSUInteger)count;
+ (instancetype)zip:(id<NSFastEnumeration>)streams;
+ (instancetype)zip:(id<NSFastEnumeration>)streams reduce:(id (^)())reduceBlock;
+ (instancetype)concat:(id<NSFastEnumeration>)streams;
- (instancetype)scanWithStart:(id)startingValue reduce:(id (^)(id running, id next))block;
- (instancetype)scanWithStart:(id)startingValue reduceWithIndex:(id (^)(id running, id next, NSUInteger index))reduceBlock;
- (instancetype)combinePreviousWithStart:(id)start reduce:(id (^)(id previous, id current))reduceBlock;
- (instancetype)takeUntilBlock:(BOOL (^)(id x))predicate;
- (instancetype)takeWhileBlock:(BOOL (^)(id x))predicate;
- (instancetype)skipUntilBlock:(BOOL (^)(id x))predicate;
- (instancetype)skipWhileBlock:(BOOL (^)(id x))predicate;
- (instancetype)distinctUntilChanged;

@end

@interface RACStream (Unavailable)

- (instancetype)sequenceMany:(RACStream * (^)(void))block __attribute__((unavailable("Use -flattenMap: instead")));
- (instancetype)scanWithStart:(id)startingValue combine:(id (^)(id running, id next))block __attribute__((unavailable("Renamed to -scanWithStart:reduce:")));
- (instancetype)mapPreviousWithStart:(id)start reduce:(id (^)(id previous, id current))combineBlock __attribute__((unavailable("Renamed to -combinePreviousWithStart:reduce:")));

@end
