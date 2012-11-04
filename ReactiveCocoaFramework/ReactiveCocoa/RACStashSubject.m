//
//  RACStashSubject.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 11/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACStashSubject.h"
#import "RACSubscribable+Private.h"
#import "RACSubscriber.h"
#import "RACTuple.h"
#import "RACDisposable.h"

@interface RACStashSubject ()
@property (nonatomic, strong) NSMutableArray *valuesReceived;
@property (nonatomic, assign) BOOL latestValueOnly;
@property (assign) BOOL hasCompletedAlready;
@property (strong) NSError *error;
@end


@implementation RACStashSubject

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
    [self.valuesReceived removeAllObjects];
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
  __block BOOL nextReceived = NO;
  [super performBlockOnEachSubscriber:^(id<RACSubscriber> subscriber) {
    [subscriber sendNext:value];
    nextReceived = YES;
  }];
	
  if (!nextReceived) {
    @synchronized(self.valuesReceived) {
      if (self.latestValueOnly) {
        [self.valuesReceived removeAllObjects];
      }
      [self.valuesReceived addObject:value ? : [RACTupleNil tupleNil]];
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
@synthesize latestValueOnly;
@synthesize hasCompletedAlready;
@synthesize error;

+ (instancetype)stashSubjectWithLatestValueOnly:(BOOL)latestValueOnly {
	RACStashSubject *subject = [self subject];
	subject.latestValueOnly = latestValueOnly;
	return subject;
}

@end
