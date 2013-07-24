//
//  RACKVOBinding.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 27/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACKVOBinding.h"
#import "EXTScope.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"
#import "NSObject+RACKVOWrapper.h"
#import "NSObject+RACPropertySubscribing.h"
#import "NSString+RACKeyPathUtilities.h"
#import "RACBinding.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACReplaySubject.h"
#import "RACSignal+Operations.h"
#import "RACSubscriber+Private.h"
#import "RACSubject.h"

// Key for the array of RACKVOBinding's additional thread local
// data in the thread dictionary.
static NSString * const RACKVOBindingDataDictionaryKey = @"RACKVOBindingKey";

// Wrapper class for additional thread local data.
@interface RACKVOBindingData : NSObject

// The flag used to ignore updates the binding itself has triggered.
@property (nonatomic, assign) BOOL ignoreNextUpdate;

// The current -willChangeValueForKey:/-didChangeValueForKey: call stack depth.
@property (nonatomic, assign) NSUInteger stackDepth;

// A pointer to the owner of the data. Only use this for pointer comparison,
// never as an object reference.
@property (nonatomic, assign) void *owner;

+ (instancetype)dataForBinding:(RACKVOBinding *)binding;

@end

@interface RACKVOBinding ()

// The object whose key path the binding is wrapping.
@property (atomic, unsafe_unretained) NSObject *target;

// The key path the binding is wrapping.
@property (nonatomic, copy, readonly) NSString *keyPath;

// Returns the existing thread local data container or nil if none exists.
@property (nonatomic, strong, readonly) RACKVOBindingData *currentThreadData;

// Creates the thread local data container for the binding.
- (void)createCurrentThreadData;

// Destroy the thread local data container for the binding.
- (void)destroyCurrentThreadData;

@end

@implementation RACKVOBinding

#pragma mark Properties

- (RACKVOBindingData *)currentThreadData {
	NSMutableArray *dataArray = NSThread.currentThread.threadDictionary[RACKVOBindingDataDictionaryKey];

	for (RACKVOBindingData *data in dataArray) {
		if (data.owner == (__bridge void *)self) return data;
	}

	return nil;
}

#pragma mark Lifecycle

- (id)initWithTarget:(NSObject *)target keyPath:(NSString *)keyPath nilValue:(id)nilValue {
	NSCParameterAssert(keyPath.rac_keyPathComponents.count > 0);

	self = [super init];
	if (self == nil) return nil;

	_target = target;
	_keyPath = [keyPath copy];

	[self.leftEndpoint setNameWithFormat:@"[-initWithTarget: %@ keyPath: %@ nilValue: %@] leftEndpoint", target, keyPath, nilValue];
	[self.rightEndpoint setNameWithFormat:@"[-initWithTarget: %@ keyPath: %@ nilValue: %@] rightEndpoint", target, keyPath, nilValue];

	// Observe the key path on target for changes. Update the value of stackDepth
	// accordingly and forward the changes to updatesSubject.
	//
	// Intentionally capturing `self` strongly in the blocks below, so the
	// binding object stays alive while observing.
	RACDisposable *observationDisposable = [target rac_observeKeyPath:keyPath options:NSKeyValueObservingOptionPrior | NSKeyValueObservingOptionInitial observer:nil block:^(id value, NSDictionary *change) {
		RACKVOBindingData *data = self.currentThreadData;
		
		// If the change is prior we only increase the stack depth if it was
		// triggered by the last path component, we don't do anything otherwise.
		if ([change[NSKeyValueChangeNotificationIsPriorKey] boolValue]) {
			if ([change[RACKeyValueChangeAffectedOnlyLastComponentKey] boolValue]) {
				// Don't worry about the data being nil, if it is it means the binding
				// hasn't received a value since the latest ignored one anyway.
				++data.stackDepth;
			}

			return;
		}
		
		// From here the change isn't prior.

		// The binding only triggers changes to the last path component, if the
		// change wasn't triggered by the last path component, or was triggered by
		// a deallocation, it definitely wasn't triggered by this binding, so just
		// forward it.
		if (![change[RACKeyValueChangeAffectedOnlyLastComponentKey] boolValue] || [change[RACKeyValueChangeCausedByDeallocationKey] boolValue]) {
			[self.leftEndpoint sendNext:value];
			return;
		}

		--data.stackDepth;
		NSCAssert(data.stackDepth != NSUIntegerMax, @"%@ received -didChangeValueForKey: without corresponding -willChangeValueForKey:", self);

		// If the current stackDepth is greater than 0, then the change was
		// triggered by a callback on -willChangeValueForKey:, and not by the
		// binding itself. If however the stackDepth is 0, and ignoreNextUpdate is
		// set, the changes was triggered by this binding and should not be
		// forwarded.
		if (data.stackDepth == 0 && data.ignoreNextUpdate) {
			[self destroyCurrentThreadData];
			return;
		}

		[self.leftEndpoint sendNext:value];
	}];
	
	NSString *keyPathByDeletingLastKeyPathComponent = keyPath.rac_keyPathByDeletingLastKeyPathComponent;
	NSArray *keyPathComponents = keyPath.rac_keyPathComponents;
	NSUInteger keyPathComponentsCount = keyPathComponents.count;
	NSString *lastKeyPathComponent = keyPathComponents.lastObject;

	// Update the value of the property with the values received.
	[[self.leftEndpoint
		finally:^{
			[observationDisposable dispose];
		}]
		subscribeNext:^(id x) {
			// Check the value of the second to last key path component. Since the
			// binding can only update the value of a property on an object, and not
			// update intermediate objects, it can only update the value of the whole
			// key path if this object is not nil.
			NSObject *object = (keyPathComponentsCount > 1 ? [self.target valueForKeyPath:keyPathByDeletingLastKeyPathComponent] : self.target);
			if (object == nil) return;

			// Set the ignoreNextUpdate flag before setting the value so this binding
			// ignores the value in the subsequent -didChangeValueForKey: callback.
			[self createCurrentThreadData];
			self.currentThreadData.ignoreNextUpdate = YES;

			[object setValue:x ?: nilValue forKey:lastKeyPathComponent];
		} error:^(NSError *error) {
			NSCAssert(NO, @"Received error in %@: %@", self, error);
			
			// Log the error if we're running with assertions disabled.
			NSLog(@"Received error in %@: %@", self, error);
		}];
	
	// Capture `self` weakly for the target's deallocation disposable, so we can
	// freely deallocate if we complete before then.
	@weakify(self);
	
	[target.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
		@strongify(self);
		[self.leftEndpoint sendCompleted];
		self.target = nil;
	}]];
	
	return self;
}

- (void)createCurrentThreadData {
	NSMutableArray *dataArray = NSThread.currentThread.threadDictionary[RACKVOBindingDataDictionaryKey];
	if (dataArray == nil) {
		dataArray = [NSMutableArray array];
		NSThread.currentThread.threadDictionary[RACKVOBindingDataDictionaryKey] = dataArray;
		[dataArray addObject:[RACKVOBindingData dataForBinding:self]];
		return;
	}

	for (RACKVOBindingData *data in dataArray) {
		if (data.owner == (__bridge void *)self) return;
	}

	[dataArray addObject:[RACKVOBindingData dataForBinding:self]];
}

- (void)destroyCurrentThreadData {
	NSMutableArray *dataArray = NSThread.currentThread.threadDictionary[RACKVOBindingDataDictionaryKey];
	NSUInteger index = [dataArray indexOfObjectPassingTest:^ BOOL (RACKVOBindingData *data, NSUInteger idx, BOOL *stop) {
		return data.owner == (__bridge void *)self;
	}];

	if (index != NSNotFound) [dataArray removeObjectAtIndex:index];
}

@end

@implementation RACKVOBinding (RACBind)

- (RACBindingEndpoint *)objectForKeyedSubscript:(NSString *)key {
	NSCParameterAssert(key != nil);

	RACBindingEndpoint *endpoint = [self valueForKey:key];
	NSCAssert([endpoint isKindOfClass:RACBindingEndpoint.class], @"Key \"%@\" does not identify a binding endpoint", key);
	
	return endpoint;
}

- (void)setObject:(RACBindingEndpoint *)otherEndpoint forKeyedSubscript:(NSString *)key {
	NSCParameterAssert(otherEndpoint != nil);

	[[self objectForKeyedSubscript:key] bindFromEndpoint:otherEndpoint];
}

@end

@implementation RACKVOBindingData

+ (instancetype)dataForBinding:(RACKVOBinding *)binding {
	RACKVOBindingData *data = [[self alloc] init];
	data->_owner = (__bridge void *)binding;
	return data;
}

@end
