//
//  NSObject+RACPropertySubscribing.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/EXTKeyPathCoding.h>
#import <ReactiveCocoa/metamacros.h>

typedef enum _RACAbleType : NSInteger {
	RACAbleTypeCurrent,						// RACAble(...), sends current value after any change
	RACAbleTypeCurrentWithPrevious,			// RACAblePrevious(...), sends previous and current values in tuple after setting
	RACAbleTypeInitialCurrent,				// RACAbleWithStart(...), sends current value after any change and begins immediately
	RACAbleTypeInitialCurrentWithPrevious,	// RACAblePreviousWithStart(...), sends previous and current values in tuple after setting and begins immediately
	RACAbleTypePrior,						// RACAblePrior(...), sends current value before setting
	RACAbleTypeInsert,						// RACAbleInsert(...), sends inserted objects and their new indexes in tuple after insertion
	RACAbleTypeRemove,						// RACAbleRemove(...), sends removed objects and their old indexes in tuple after removal
	RACAbleTypeReplace,						// RACAbleInsert(...), sends replaced objects, their replacements and indexes in tuple after replacement
} RACAbleType;

// Creates a signal which observes the given key path for changes.
//
// If given one argument, the key path is assumed to be relative to self.
// If given two arguments, the first argument is the object to observe, and the
// second argument is the key path to observe upon it.
//
// In either case, the observation continues until the observed object _or self_
// is deallocated. No intermediate objects along the key path should be
// deallocated while the observation exists.
//
// Examples
//
//   // Observes self, and doesn't stop until self is deallocated. The array
//   // controller should not be deallocated during this time.
//   RACSignal *signal1 = RACAble(self.arrayController.items);
//
//   // Observes obj.arrayController, and stops when _self_ or the array
//   // controller is deallocated.
//   RACSignal *signal2 = RACAble(obj.arrayController, items);
//
// Returns a signal which sends a value every time the value at the given key
// path changes, and sends completed if self is deallocated (no matter which
// variant of RACAble was used).
#define RACAble(...)					_RACAbleOfType(RACAbleTypeCurrent, __VA_ARGS__)
#define RACAblePrevious(...)			_RACAbleOfType(RACAbleTypeCurrentWithPrevious, __VA_ARGS__)
#define RACAbleWithStart(...)			_RACAbleOfType(RACAbleTypeInitialCurrent, __VA_ARGS__)
#define RACAblePreviousWithStart(...)	_RACAbleOfType(RACAbleTypeInitialCurrentWithPrevious, __VA_ARGS__)
#define RACAblePrior(...)				_RACAbleOfType(RACAbleTypePrior, __VA_ARGS__)
#define RACAbleInsert(...)				_RACAbleOfType(RACAbleTypeInsert, __VA_ARGS__)
#define RACAbleRemove(...)				_RACAbleOfType(RACAbleTypeRemove, __VA_ARGS__)
#define RACAbleReplace(...)				_RACAbleOfType(RACAbleTypeReplace, __VA_ARGS__)

// Do not use these directly. Use RACAbles above.
#define _RACAbleOfType(type, ...) metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__))(_RACAbleObject(type, self, __VA_ARGS__))(_RACAbleObject(type, __VA_ARGS__))
#define _RACAbleObject(theType, object, property) [object rac_signalForKeyPath:@keypath(object, property) observer:self type:theType]

@class RACDisposable;
@class RACCompoundDisposable;
@class RACSignal;

@interface NSObject (RACPropertySubscribing)

// The compound disposable which will be disposed of when the receiver is
// deallocated.
@property (atomic, readonly, strong) RACCompoundDisposable *rac_deallocDisposable;

// Creates a signal for observing the value at the given keypath.
- (RACSignal *)rac_signalForKeyPath:(NSString *)keyPath observer:(NSObject *)observer;

// Creates a signal for observing the value at the given keypath on the source
// object.
- (RACSignal *)rac_signalFor:(NSObject *)object keyPath:(NSString *)keyPath observer:(NSObject *)observer;

// Creates a signal for observing the value at the given keypath on the source
// object. The signal returns a change dictionary.
+ (RACSignal *)rac_signalWithChangesFor:(NSObject *)object keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options observer:(NSObject *)observer;

// Keeps the value of the KVC-compliant keypath up-to-date with the latest value
// sent by the signal.
- (RACDisposable *)rac_deriveProperty:(NSString *)keyPath from:(RACSignal *)signal;

// Adds a disposable which will be disposed when the receiver deallocs.
- (void)rac_addDeallocDisposable:(RACDisposable *)disposable;

@end
