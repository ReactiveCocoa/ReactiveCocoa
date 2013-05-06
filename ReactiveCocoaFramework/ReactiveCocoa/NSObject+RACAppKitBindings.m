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

// A class for the RACAppKitBindings to bind to.
// In turn, it sends the subscriber values.
@interface RACBindingProxy : NSObject

@property (nonatomic, strong) id value;
@property (nonatomic, weak) id subscriber;

@end

@implementation RACBindingProxy

@synthesize value = _value;

- (void)setValue:(id)value {
	// Need to keep the value around, for initial value.
	_value = value;
	[_subscriber sendNext:value];
}

- (id)value {
	return _value;
}

@end

@implementation NSObject (RACAppKitBindings)

- (RACBinding *)rac_bind:(NSString *)binding {
	return [self rac_bind:binding nilValue:nil];
}

- (RACBinding *)rac_bind:(NSString *)binding nilValue:(id)nilValue {
	__block RACBindingProxy *proxy = [[RACBindingProxy alloc] init];
	[self bind:binding toObject:proxy withKeyPath:@keypath(proxy, value) options:@{NSContinuouslyUpdatesValueBindingOption : @YES, NSNullPlaceholderBindingOption : nilValue}];
	
	RACSignal *signal = [[[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		proxy.subscriber = subscriber;
		return [RACDisposable disposableWithBlock:^{
			[self unbind:binding];
		}];
		
	}] startWith:[nilValue copy]]
	setNameWithFormat:@"%@ -rac_bind", self];
	
	RACSubscriber *subscriber = [RACSubscriber subscriberWithNext:^(id x) {
		[proxy setValue:x];
	} error:^(NSError *error) {
		NSAssert(NO, @"Received error in RACAppKitBindings %@: %@", self, error);

		NSLog(@"Received error in RACAppKitBindings %@: %@", self, error);
	} completed:nil];
	
	return [[RACBinding alloc] initWithValueSignal:signal subscriber:subscriber];
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
