//
//  RACStream.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-31.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACStream;

// A block which accepts a value from a RACStream and returns a new instance
// of the same stream class.
//
// Setting `stop` to `YES` will cause the bind to terminate after the returned
// value. Returning `nil` will result in immediate termination.
typedef RACStream * (^RACStreamBindBlock)(id value, BOOL *stop);

// An abstract class representing any stream of values.
//
// This class represents a monad, upon which many stream-based operations can
// be built.
//
// When subclassing RACStream, only the methods in the main @interface body need
// to be overridden.
@interface RACStream : NSObject

// Returns an empty stream.
+ (instancetype)empty;

// Lifts `value` into the stream monad.
//
// Returns a stream containing only the given value.
+ (instancetype)return:(id)value;

// Lazily binds a block to the values in the receiver.
//
// This should only be used if you need to terminate the bind early, or close
// over some state. -flattenMap: is more appropriate for all other cases.
//
// block - A block returning a RACStreamBindBlock. This block will be invoked
//         each time the bound stream is re-evaluated. This block must not be
//         nil or return nil.
//
// Returns a new stream which represents the combined result of all lazy
// applications of `block`.
- (instancetype)bind:(RACStreamBindBlock (^)(void))block;

// Appends the values of `stream` to the values in the receiver.
//
// stream - A stream to concatenate. This must be an instance of the same
//          concrete class as the receiver, and should not be `nil`.
//
// Returns a new stream representing the receiver followed by `stream`.
- (instancetype)concat:(RACStream *)stream;

// Combines the values in `streams` using `reduceBlock`. `reduceBlock` will be
// called with the first value of each stream, then with the second value of
// each stream, and so forth until at least one of the streams is exhausted.
//
// streams       - The streams to combine. These must all be instances of the
//                 same concrete class implementing the protocol. If this
//                 collection is empty, the returned stream will be empty.
// reduceBlock   - The block which reduces the values from all the streams
//                 into one value. It should take as many arguments as the
//                 number of streams given. Each argument will be an object
//                 argument, wrapped as needed. If nil, the returned stream
//                 will contain a RACTuple of the values.
//
// Returns a new stream containing the return values of `reduceBlock` applied to
// the values contained in the input streams, or if `reduceBlock` is nil, tuples
// of the same values
+ (instancetype)zip:(id<NSFastEnumeration>)streams reduce:(id)reduceBlock;

@end

// This extension contains functionality to support naming streams for
// debugging.
//
// Subclasses do not need to override the methods here.
@interface RACStream ()

// The name of the stream. This is for debugging/human purposes only.
@property (copy) NSString *name;

// Sets the name of the receiver to the given format string.
//
// This is for debugging purposes only, and won't do anything unless the DEBUG
// preprocessor macro is defined.
//
// Returns the receiver, for easy method chaining.
- (instancetype)setNameWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);

@end

// Operations built on the RACStream primitives.
//
// These methods do not need to be overridden, although subclasses may
// occasionally gain better performance from doing so.
@interface RACStream (Operations)

// Maps `block` across the values in the receiver and flattens the result.
//
// This corresponds to the `SelectMany` method in Rx.
//
// block - A block which accepts the values in the receiver and returns a new
//         instance of the receiver's class. This block should not return `nil`.
//
// Returns a new stream which represents the combined streams resulting from
// mapping `block`.
- (instancetype)flattenMap:(RACStream * (^)(id value))block;

// Flattens a stream of streams.
//
// This corresponds to the `Merge` method in Rx.
//
// Returns a stream consisting of the combined streams obtained from the
// receiver.
- (instancetype)flatten;

// Maps `block` across the values in the receiver.
//
// This corresponds to the `Select` method in Rx.
//
// Returns a new stream with the mapped values.
- (instancetype)map:(id (^)(id value))block;

// Replace each value in the receiver with the given object.
//
// Returns a new stream which includes the given object once for each value in
// the receiver.
- (instancetype)mapReplace:(id)object;

// Maps the combination of the previous and current objects to one object.
//
// start        - The value passed into `combineBlock` as `previous` for the
//                first value.
// combineBlock - The block that combines the previous value and the current
//                value to create the combined value. Cannot be nil.
//
// Returns a new stream consisting of the return values from each application of
// `combineBlock`.
- (instancetype)mapPreviousWithStart:(id)start combine:(id (^)(id previous, id current))combineBlock;

// Filters out values in the receiver that don't pass the given test.
//
// This corresponds to the `Where` method in Rx.
//
// Returns a new stream with only those values that passed.
- (instancetype)filter:(BOOL (^)(id value))block;

// Returns a stream consisting of `value`, followed by the values in the
// receiver.
- (instancetype)startWith:(id)value;

// Skips the first `skipCount` values in the receiver.
//
// Returns the receiver after skipping the first `skipCount` values. If
// `skipCount` is greater than the number of values in the stream, an empty
// stream is returned.
- (instancetype)skip:(NSUInteger)skipCount;

// Returns a stream of the first `count` values in the receiver. If `count` is
// greater than or equal to the number of values in the stream, a stream
// equivalent to the receiver is returned.
- (instancetype)take:(NSUInteger)count;

// Invokes the given `block` for each value in the receiver.
//
// block - A block which returns a new instance of the receiver's class.
//
// Returns a new stream which represents the combined result of all invocations
// of `block`.
- (instancetype)sequenceMany:(RACStream * (^)(void))block;

// Invokes +zip:reduce: with a nil `reduceBlock`.
+ (instancetype)zip:(id<NSFastEnumeration>)streams;

// Returns a stream obtained by concatenating `streams` in order.
+ (instancetype)concat:(id<NSFastEnumeration>)streams;

// Combines values in the receiver from left to right using the given block.
//
// The algorithm proceeds as follows:
//
//  1. `startingValue` is passed into the block as the `running` value, and the
//  first element of the receiver is passed into the block as the `next` value.
//  2. The result of the invocation is added to the returned stream.
//  3. The result of the invocation (`running`) and the next element of the
//  receiver (`next`) is passed into `block`.
//  4. Steps 2 and 3 are repeated until all elements have been processed.
//
// startingValue - The value to be combined with the first element of the
//                 receiver. This value may be `nil`.
// block         - A block that describes how to combine elements of the
//                 receiver. If the receiver is empty, this block will never be
//                 invoked.
//
// Returns a new stream that consists of each application of `block`. If the
// receiver is empty, an empty stream is returned.
- (instancetype)scanWithStart:(id)startingValue combine:(id (^)(id running, id next))block;

// Takes values until the given block returns `YES`.
//
// Returns a stream of the initial values in the receiver that fail `predicate`.
// If `predicate` never returns `YES`, a stream equivalent to the receiver is
// returned.
- (instancetype)takeUntilBlock:(BOOL (^)(id x))predicate;

// Takes values until the given block returns `NO`.
//
// Returns a stream of the initial values in the receiver that pass `predicate`.
// If `predicate` never returns `NO`, a stream equivalent to the receiver is
// returned.
- (instancetype)takeWhileBlock:(BOOL (^)(id x))predicate;

// Skips values until the given block returns `YES`.
//
// Returns a stream containing the values of the receiver that follow any
// initial values failing `predicate`. If `predicate` never returns `YES`,
// an empty stream is returned.
- (instancetype)skipUntilBlock:(BOOL (^)(id x))predicate;

// Skips values until the given block returns `NO`.
//
// Returns a stream containing the values of the receiver that follow any
// initial values passing `predicate`. If `predicate` never returns `NO`, an
// empty stream is returned.
- (instancetype)skipWhileBlock:(BOOL (^)(id x))predicate;

@end
