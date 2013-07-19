//
//  RACObservablePropertySubject.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 27/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACObservablePropertySubject.h"
#import "EXTScope.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"
#import "NSObject+RACKVOWrapper.h"
#import "NSObject+RACPropertySubscribing.h"
#import "NSString+RACKeyPathUtilities.h"
#import "RACBinding+Private.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACPropertySubject+Private.h"
#import "RACReplaySubject.h"
#import "RACSignal+Operations.h"
#import "RACSubscriber+Private.h"
#import "RACSubject.h"

@class RACObservablePropertyBinding;

// Key for the array of RACObservablePropertyBinding's additional thread local
// data in the thread dictionary.
static NSString * const RACObservablePropertyBindingDataDictionaryKey = @"RACObservablePropertyBindingKey";

@interface RACObservablePropertySubject ()

// Forwards `error` and `completed` events to any bindings.
@property (nonatomic, readonly, strong) RACSubject *terminationSubject;

// The object whose key path the RACObservablePropertySubject is wrapping.
@property (atomic, unsafe_unretained) NSObject *target;

// The key path the RACObservablePropertySubject is wrapping.
@property (nonatomic, readonly, copy) NSString *keyPath;

// The value to set when `nil` is sent to the receiver.
@property (nonatomic, readonly, strong) id nilValue;

@end

// Wrapper class for additional thread local data.
@interface RACObservablePropertyBindingData : NSObject

// The flag used to ignore updates the binding itself has triggered.
@property (nonatomic, assign) BOOL ignoreNextUpdate;

// The current -willChangeValueForKey:/-didChangeValueForKey: call stack depth.
@property (nonatomic, assign) NSUInteger stackDepth;

// A pointer to the owner of the data. Only use this for pointer comparison,
// never as an object reference.
@property (nonatomic, assign) void *owner;

+ (instancetype)dataForBinding:(RACObservablePropertyBinding *)binding;

@end

// A binding to a key path on an object.
@interface RACObservablePropertyBinding : RACBinding

// Create a new binding for `keyPath` on `target`.
//
// target             - The object to observe. This must not be nil.
// keyPath            - The key path to observe, relative to the `target`. This
//                      must not be nil.
// nilValue           - The value to set when `nil` is sent to the binding.
// terminationSubject - A subject to watch for `error` and `completed` events.
//                      The binding will forward any such events to its
//                      subscribers. If the binding receives an `error` or
//                      `completed` event, it will also send it upon this
//                      subject. This argument must not be nil.
+ (instancetype)bindingWithTarget:(NSObject *)target keyPath:(NSString *)keyPath nilValue:(id)nilValue terminationSubject:(RACSubject *)terminationSubject;

// The object whose key path the binding is wrapping.
@property (atomic, unsafe_unretained) NSObject *target;

// The key path the binding is wrapping.
@property (nonatomic, readonly, copy) NSString *keyPath;

// Returns the existing thread local data container or nil if none exists.
- (RACObservablePropertyBindingData *)currentThreadData;

// Creates the thread local data container for the binding.
- (void)createCurrentThreadData;

// Destroy the thread local data container for the binding.
- (void)destroyCurrentThreadData;

@end

@implementation RACObservablePropertySubject

#pragma mark API

+ (instancetype)propertyWithTarget:(NSObject *)target keyPath:(NSString *)keyPath nilValue:(id)nilValue {
	if (target == nil) return nil;
	NSCParameterAssert(keyPath.rac_keyPathComponents.count > 0);

	RACObservablePropertySubject *property = [self alloc];
	RACReplaySubject *terminationSubject = [RACReplaySubject replaySubjectWithCapacity:1];
	@weakify(property);

	RACSignal *exposedSignal = [[[RACSignal
		defer:^{
			@strongify(property);
			return [property.target rac_valuesForKeyPath:property.keyPath observer:property];
		}]
		takeUntil:terminationSubject]
		setNameWithFormat:@"+propertyWithTarget: %@ keyPath: %@", [target rac_description], keyPath];

	id<RACSubscriber> exposedSubscriber = [RACSubscriber subscriberWithNext:^(id x) {
		@strongify(property);
		[property.target setValue:x ?: property.nilValue forKeyPath:property.keyPath];
	} error:^(NSError *error) {
		@strongify(property);
		NSCAssert(NO, @"Received error in RACObservablePropertySubject for key path \"%@\" on %@: %@", property.keyPath, property.target, error);

		// Log the error if we're running with assertions disabled.
		NSLog(@"Received error in RACObservablePropertySubject for key path \"%@\" on %@: %@", property.keyPath, property.target, error);

		[property.terminationSubject sendError:error];
	} completed:^{
		@strongify(property);
		[property.terminationSubject sendCompleted];
	}];
	
	property = [property initWithSignal:exposedSignal subscriber:exposedSubscriber];
	if (property == nil) return nil;

	property->_target = target;
	property->_keyPath = [keyPath copy];
	property->_nilValue = nilValue;
	property->_terminationSubject = terminationSubject;
	
	[target.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
		@strongify(property);

		[property.terminationSubject sendCompleted];
		property.target = nil;
	}]];
	
	return property;
}

- (RACBinding *)binding {
	return [RACObservablePropertyBinding bindingWithTarget:self.target keyPath:self.keyPath nilValue:self.nilValue terminationSubject:self.terminationSubject];
}

@end

@implementation RACObservablePropertySubject (RACBind)

- (RACBinding *)objectForKeyedSubscript:(id)key {
	return [self valueForKey:key];
}

- (void)setObject:(RACBinding *)obj forKeyedSubscript:(id)key {
	RACBinding *binding = [self valueForKey:key];
	[obj subscribe:binding];
	[[binding skip:1] subscribe:obj];
}

@end

@implementation RACObservablePropertyBinding

#pragma mark API

+ (instancetype)bindingWithTarget:(NSObject *)target keyPath:(NSString *)keyPath nilValue:(id)nilValue terminationSubject:(RACSubject *)terminationSubject {
	if (target == nil) return nil;
	NSCParameterAssert(keyPath.rac_keyPathComponents.count > 0);

	RACObservablePropertyBinding *binding = [self alloc];
	@weakify(binding);

	// The subject used to multicast changes to the property to the binding's
	// subscribers.
	RACSubject *updatesSubject = [RACSubject subject];

	// Observe the key path on target for changes. Update the value of stackDepth
	// accordingly and forward the changes to updatesSubject.
	RACDisposable *observationDisposable = [target rac_observeKeyPath:keyPath options:NSKeyValueObservingOptionPrior observer:binding block:^(id value, NSDictionary *change) {
		@strongify(binding);
		RACObservablePropertyBindingData *data = binding.currentThreadData;
		
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
			[updatesSubject sendNext:value];
			return;
		}

		--data.stackDepth;
		NSCAssert(data.stackDepth != NSUIntegerMax, @"%@ called didChangeValueForKey: without corresponding willChangeValueForKey:", keyPath);

		// If the current stackDepth is greater than 0, then the change was
		// triggered by a callback on -willChangeValueForKey:, and not by the
		// binding itself. If however the stackDepth is 0, and ignoreNextUpdate is
		// set, the changes was triggered by this binding and should not be
		// forwarded.
		if (data.stackDepth == 0 && data.ignoreNextUpdate) {
			[binding destroyCurrentThreadData];
			return;
		}

		[updatesSubject sendNext:value];
	}];

	[terminationSubject subscribeError:^(NSError *error) {
		[observationDisposable dispose];
	} completed:^{
		[observationDisposable dispose];
	}];

	// On subscription first send the property's current value then subscribe the
	// subscriber to the updatesSubject for new values when they change.
	RACSignal *exposedSignal = [[[RACSignal
		defer:^{
			@strongify(binding);
			return [updatesSubject startWith:[binding.target valueForKeyPath:binding.keyPath]];
		}]
		takeUntil:terminationSubject]
		setNameWithFormat:@"[+propertyWithTarget: %@ keyPath: %@] -binding", [target rac_description], keyPath];
	
	NSString *keyPathByDeletingLastKeyPathComponent = keyPath.rac_keyPathByDeletingLastKeyPathComponent;
	NSArray *keyPathComponents = keyPath.rac_keyPathComponents;
	NSUInteger keyPathComponentsCount = keyPathComponents.count;
	NSString *lastKeyPathComponent = keyPathComponents.lastObject;

	// Update the value of the property with the values received.
	id<RACSubscriber> exposedSubscriber = [RACSubscriber subscriberWithNext:^(id x) {
		@strongify(binding);

		// Check the value of the second to last key path component. Since the
		// binding can only update the value of a property on an object, and not
		// update intermediate objects, it can only update the value of the whole
		// key path if this object is not nil.
		NSObject *object = (keyPathComponentsCount > 1 ? [binding.target valueForKeyPath:keyPathByDeletingLastKeyPathComponent] : binding.target);
		if (object == nil) return;

		// Set the ignoreNextUpdate flag before setting the value so this binding
		// ignores the value in the subsequent -didChangeValueForKey: callback.
		[binding createCurrentThreadData];
		binding.currentThreadData.ignoreNextUpdate = YES;

		[object setValue:x ?: nilValue forKey:lastKeyPathComponent];
	} error:^(NSError *error) {
		@strongify(binding);
		NSCAssert(NO, @"Received error in -[RACObservablePropertySubject binding] for key path \"%@\" on %@: %@", binding.keyPath, binding.target, error);
		
		// Log the error if we're running with assertions disabled.
		NSLog(@"Received error in -[RACObservablePropertySubject binding] for key path \"%@\" on %@: %@", binding.keyPath, binding.target, error);

		[terminationSubject sendError:error];
	} completed:^{
		[terminationSubject sendCompleted];
	}];

	binding = [binding initWithSignal:exposedSignal subscriber:exposedSubscriber];
	if (binding == nil) return nil;

	binding->_target = target;
	binding->_keyPath = [keyPath copy];
	
	[target.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
		@strongify(binding);
		[terminationSubject sendCompleted];
		binding.target = nil;
	}]];
	
	return binding;
}

- (RACObservablePropertyBindingData *)currentThreadData {
	NSMutableArray *dataArray = NSThread.currentThread.threadDictionary[RACObservablePropertyBindingDataDictionaryKey];

	for (RACObservablePropertyBindingData *data in dataArray) {
		if (data.owner == (__bridge void *)self) return data;
	}

	return nil;
}

- (void)createCurrentThreadData {
	NSMutableArray *dataArray = NSThread.currentThread.threadDictionary[RACObservablePropertyBindingDataDictionaryKey];
	if (dataArray == nil) {
		dataArray = [NSMutableArray array];
		NSThread.currentThread.threadDictionary[RACObservablePropertyBindingDataDictionaryKey] = dataArray;
		[dataArray addObject:[RACObservablePropertyBindingData dataForBinding:self]];
		return;
	}

	for (RACObservablePropertyBindingData *data in dataArray) {
		if (data.owner == (__bridge void *)self) return;
	}

	[dataArray addObject:[RACObservablePropertyBindingData dataForBinding:self]];
}

- (void)destroyCurrentThreadData {
	NSMutableArray *dataArray = NSThread.currentThread.threadDictionary[RACObservablePropertyBindingDataDictionaryKey];

	NSUInteger index = [dataArray indexOfObjectPassingTest:^ BOOL (RACObservablePropertyBindingData *data, NSUInteger idx, BOOL *stop) {
		return data.owner == (__bridge void *)self;
	}];
	if (index != NSNotFound) [dataArray removeObjectAtIndex:index];
}

@end

@implementation RACObservablePropertyBindingData

+ (instancetype)dataForBinding:(RACObservablePropertyBinding *)binding {
	RACObservablePropertyBindingData *data = [[self alloc] init];
	data->_owner = (__bridge void *)binding;
	return data;
}

@end

@implementation NSObject (RACObservablePropertySubjectDeprecated)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

- (RACObservablePropertySubject *)rac_propertyForKeyPath:(NSString *)keyPath {
	return [RACObservablePropertySubject propertyWithTarget:self keyPath:keyPath nilValue:nil];
}

#pragma clang diagnostic pop

@end
