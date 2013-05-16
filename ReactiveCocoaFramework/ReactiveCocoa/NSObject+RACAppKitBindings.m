//
//  NSObject+RACAppKitBindings.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACAppKitBindings.h"

#import "EXTKeyPathCoding.h"
#import "EXTScope.h"

#import "RACSubscriber.h"
#import "RACSignal.h"
#import "RACDisposable.h"
#import "RACBinding+Private.h"
#import "RACValueTransformer.h"
#import "RACTuple.h"

// A class for the RACAppKitBindings to bind to.
// In turn, it sends the subscriber values.
@interface RACBindingProxy : NSObject

@property (nonatomic, strong) id value;
@property (nonatomic, strong) id nilValue;
@property (nonatomic, weak) id subscriber;
@property (nonatomic, weak) RACBinding *binder;

@end

@implementation RACBindingProxy

@synthesize value = _value;

- (void)setValue:(id)value {
	// Need to keep the value around, for initial value.
	if (value == nil) {
		_value = self.nilValue;
	} else {
		_value = value;
	}
	
	[self.subscriber sendNext:[RACTuple tupleWithObjects:_value, self.binder, nil]];
}

- (id)value {
	return _value;
}

@end

@implementation NSObject (RACAppKitBindings)

- (RACBinding *)rac_bind:(NSString *)binding {
	return [self rac_bind:binding options:@{NSContinuouslyUpdatesValueBindingOption : @YES, NSNullPlaceholderBindingOption : [NSNull null]}];
}


- (RACBinding *)rac_bind:(NSString *)binding nilValue:(id)nilValue {
	return [self rac_bind:binding options:@{NSContinuouslyUpdatesValueBindingOption : @YES, NSNullPlaceholderBindingOption : nilValue}];
}

- (RACBinding *)rac_bind:(NSString *)binding options:(NSDictionary *)options {
	__block RACBindingProxy *proxy = [[RACBindingProxy alloc] init];
	proxy.nilValue = options[NSNullPlaceholderBindingOption];

	[self bind:binding toObject:proxy withKeyPath:@keypath(proxy, value) options:options];
	
	RACSignal *signal = [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		[subscriber sendNext:[RACTuple tupleWithObjects:proxy.value, RACTupleNil.tupleNil, nil]];
		
		return [RACDisposable disposableWithBlock:^{
			[self unbind:binding];
		}];
	}] 
	setNameWithFormat:@"%@ -rac_bind", self];
	
	RACSubscriber *subscriber = [RACSubscriber subscriberWithNext:^(RACTuple *x) {
		[proxy setValue:x.first];
		
	} error:^(NSError *error) {
		NSAssert(NO, @"Received error in RACAppKitBindings %@: %@", self, error);

		NSLog(@"Received error in RACAppKitBindings %@: %@", self, error);
	} completed:nil];
	
	
	RACBinding *bind = [[RACBinding alloc] initWithSignal:signal subscriber:subscriber];
	proxy.binder = bind;
	
	[proxy setValue:nil];
	
	return bind;
}


#pragma mark - deprecated NSObject+RACAppKitBindings 
// See issue #361

- (void)rac_bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath {
	[self rac_bind:binding toObject:object withKeyPath:keyPath nilValue:nil];
}

- (void)rac_bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath nilValue:(id)nilValue {
	[self bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nilValue, NSNullPlaceholderBindingOption, nil]];
}

- (void)rac_bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath transform:(id (^)(id value))transformBlock {
	RACValueTransformer *transformer = [RACValueTransformer transformerWithBlock:transformBlock];
	[self bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, transformer, NSValueTransformerBindingOption, nil]];
}

- (void)rac_bind:(NSString *)binding toObject:(id)object withNegatedKeyPath:(NSString *)keyPath {
	[self bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, NSNegateBooleanTransformerName, NSValueTransformerNameBindingOption, nil]];
}

@end
