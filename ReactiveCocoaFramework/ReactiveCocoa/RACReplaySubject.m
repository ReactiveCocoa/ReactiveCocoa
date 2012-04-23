//
//  RACReplaySubject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/14/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACReplaySubject.h"
#import "RACSubscriber.h"

@interface RACReplaySubject ()
@property (nonatomic, strong) NSMutableArray *valuesReceived;
@property (nonatomic, assign) NSUInteger capacity;
@end


@implementation RACReplaySubject

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.valuesReceived = [NSMutableArray array];
	
	return self;
}


#pragma mark RACSubscribable

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	RACDisposable * disposable = [super subscribe:subscriber];
	for(id value in self.valuesReceived) {
		[subscriber sendNext:[value isKindOfClass:[NSNull class]] ? nil : value];
	}
	
	return disposable;
}


#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	[super sendNext:value];
	
	[self.valuesReceived addObject:value ? : [NSNull null]];
	
	while(self.valuesReceived.count > self.capacity) {
		[self.valuesReceived removeObjectAtIndex:0];
	}
}


#pragma mark API

@synthesize valuesReceived;
@synthesize capacity;

+ (id)replaySubjectWithCapacity:(NSUInteger)capacity {
	RACReplaySubject *subject = [self subject];
	subject.capacity = capacity;
	return subject;
}

@end
