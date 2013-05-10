//
//  RACEvent.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-01-07.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACEvent.h"

@interface RACEvent ()

// An object associated with this event. This will be used for the error and
// value properties.
@property (nonatomic, strong, readonly) id object;

// Initializes the receiver with the given type and object.
- (id)initWithEventType:(RACEventType)type object:(id)object;

@end

@implementation RACEvent

#pragma mark Properties

- (BOOL)isFinished {
	return self.eventType == RACEventTypeCompleted || self.eventType == RACEventTypeError;
}

- (NSError *)error {
	return (self.eventType == RACEventTypeError ? self.object : nil);
}

- (id)value {
	return (self.eventType == RACEventTypeNext ? self.object : nil);
}

#pragma mark Lifecycle

+ (instancetype)completedEvent {
	static dispatch_once_t pred;
	static id singleton;

	dispatch_once(&pred, ^{
		singleton = [[self alloc] initWithEventType:RACEventTypeCompleted object:nil];
	});

	return singleton;
}

+ (instancetype)eventWithError:(NSError *)error {
	return [[self alloc] initWithEventType:RACEventTypeError object:error];
}

+ (instancetype)eventWithValue:(id)value {
	return [[self alloc] initWithEventType:RACEventTypeNext object:value];
}

- (id)initWithEventType:(RACEventType)type object:(id)object {
	self = [super init];
	if (self == nil) return nil;

	_eventType = type;
	_object = object;

	return self;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

#pragma mark NSObject

- (NSString *)description {
	NSString *eventDescription = nil;

	switch (self.eventType) {
		case RACEventTypeCompleted:
			eventDescription = @"completed";
			break;

		case RACEventTypeError:
			eventDescription = [NSString stringWithFormat:@"error = %@", self.object];
			break;

		case RACEventTypeNext:
			eventDescription = [NSString stringWithFormat:@"next = %@", self.object];
			break;

		default:
			NSCAssert(NO, @"Unrecognized event type: %i", (int)self.eventType);
	}

	return [NSString stringWithFormat:@"<%@: %p>{ %@ }", self.class, self, eventDescription];
}

- (NSUInteger)hash {
	return self.eventType ^ [self.object hash];
}

- (BOOL)isEqual:(id)event {
	if (event == self) return YES;
	if (![event isKindOfClass:RACEvent.class]) return NO;
	if (self.eventType != [event eventType]) return NO;

	// Catches the nil case too.
	return self.object == [event object] || [self.object isEqual:[event object]];
}

@end
