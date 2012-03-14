//
//  RACReplaySubject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACReplaySubject.h"
#import "RACSequence+Private.h"
#import "EXTNil.h"
#import "RACObserver.h"

@interface RACReplaySubject ()
@property (nonatomic, strong) NSMutableArray *valuesReceived;
@end


@implementation RACReplaySubject

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.valuesReceived = [NSMutableArray array];
	
	return self;
}


#pragma mark RACObservable

- (id)subscribe:(RACObserver *)observer {
	id result = [super subscribe:observer];
	for(id object in self.valuesReceived) {
		if(observer.next != NULL) {
			observer.next(object);
		}
	}
	
	return result;
}


#pragma mark RACSequence

- (void)addObjectAndNilsAreOK:(id)object {
	[self.valuesReceived addObject:object ? : [EXTNil null]];
	
	[super addObjectAndNilsAreOK:object];
}


#pragma mark API

@synthesize valuesReceived;

@end
