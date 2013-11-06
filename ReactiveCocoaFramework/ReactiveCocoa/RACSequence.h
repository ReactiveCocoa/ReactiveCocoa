//
//  RACSequence.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACDeprecated.h"
#import "RACStream.h"

@class RACScheduler;
@class RACSignal;

RACDeprecated("Use RACSignal instead")
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@interface RACSequence : RACStream <NSCoding, NSCopying, NSFastEnumeration>
#pragma clang diagnostic pop

@property (nonatomic, strong, readonly) id head;
@property (nonatomic, strong, readonly) RACSequence *tail;
@property (nonatomic, copy, readonly) NSArray *array;
@property (nonatomic, copy, readonly) NSEnumerator *objectEnumerator;

@property (nonatomic, copy, readonly) RACSequence *eagerSequence;
@property (nonatomic, copy, readonly) RACSequence *lazySequence;

- (RACSignal *)signal;
- (RACSignal *)signalWithScheduler:(RACScheduler *)scheduler;

- (id)foldLeftWithStart:(id)start reduce:(id (^)(id accumulator, id value))reduce;
- (id)foldRightWithStart:(id)start reduce:(id (^)(id first, RACSequence *rest))reduce;

- (BOOL)any:(BOOL (^)(id value))block;
- (BOOL)all:(BOOL (^)(id value))block;
- (id)objectPassingTest:(BOOL (^)(id value))block;

+ (RACSequence *)sequenceWithHeadBlock:(id (^)(void))headBlock tailBlock:(RACSequence *(^)(void))tailBlock;

@end

@interface RACSequence (Unavailable)

- (id)foldLeftWithStart:(id)start combine:(id (^)(id accumulator, id value))combine __attribute__((unavailable("Renamed to -foldLeftWithStart:reduce:")));
- (id)foldRightWithStart:(id)start combine:(id (^)(id first, RACSequence *rest))combine __attribute__((unavailable("Renamed to -foldRightWithStart:reduce:")));

@end
