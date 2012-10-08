//
//  RACReplaySubject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/14/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACReplaySubject.h"
#import "RACSubscriber.h"
#import "RACTuple.h"
#import "RACDisposable.h"

const NSUInteger RACReplaySubjectUnlimitedCapacity = 0;

@interface RACReplaySubject ()
@property (nonatomic, strong) NSMutableArray *valuesReceived;
@property (nonatomic, assign) NSUInteger capacity;
@property (assign) BOOL hasCompletedAlready;
@property (strong) NSError *error;
@end


@implementation RACReplaySubject

- (instancetype)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.valuesReceived = [NSMutableArray array];
	
	return self;
}


#pragma mark RACSubscribable

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	RACDisposable *disposable = [super subscribe:subscriber];
	NSArray *valuesCopy = nil;
	@synchronized(self.valuesReceived) {
		valuesCopy = [self.valuesReceived copy];
	}
	
	for(id value in valuesCopy) {
		[subscriber sendNext:[value isKindOfClass:[RACTupleNil class]] ? nil : value];
	}
	
	if(self.hasCompletedAlready) {
		[subscriber sendCompleted];
		[disposable dispose];
	} else if(self.error != nil) {
		[subscriber sendError:self.error];
		[disposable dispose];
	}
	
	return disposable;
}


#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	[super sendNext:value];
	
	@synchronized(self.valuesReceived) {
		[self.valuesReceived addObject:value ? : [RACTupleNil tupleNil]];
		
		if(self.capacity != RACReplaySubjectUnlimitedCapacity) {
			while(self.valuesReceived.count > self.capacity) {
				[self.valuesReceived removeObjectAtIndex:0];
			}
		}
	}
}

- (void)sendCompleted {
	self.hasCompletedAlready = YES;
	
	[super sendCompleted];
}

- (void)sendError:(NSError *)e {
	self.error = e;
	
	[super sendError:e];
}


#pragma mark API

@synthesize valuesReceived;
@synthesize capacity;
@synthesize hasCompletedAlready;
@synthesize error;

+ (instancetype)replaySubjectWithCapacity:(NSUInteger)capacity {
	RACReplaySubject *subject = [self subject];
	subject.capacity = capacity;
	return subject;
}

@end
