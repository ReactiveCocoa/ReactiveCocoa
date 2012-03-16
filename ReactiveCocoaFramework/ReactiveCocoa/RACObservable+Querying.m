//
//  RACObservable+Querying.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACObservable+Querying.h"
#import "RACObserver.h"
#import "RACSubject.h"
#import "NSObject+GHExtensions.h"
#import "RACBehaviorSubject.h"

#define RACCreateWeakSelf __block __unsafe_unretained id weakSelf = self;
#define RACRedefineSelf id self = weakSelf;


@implementation RACObservable (Querying)

- (instancetype)select:(id (^)(id x))selectBlock {
	NSParameterAssert(selectBlock != NULL);
	
	RACCreateWeakSelf
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		RACRedefineSelf
		return [self subscribeNext:^(id x) {
			[observer sendNext:selectBlock(x)];
		} error:^(NSError *error) {
			[observer sendError:error];
		} completed:^{
			[observer sendCompleted];
		}];
	}];
}

- (instancetype)where:(BOOL (^)(id x))whereBlock {
	NSParameterAssert(whereBlock != NULL);
	
	RACCreateWeakSelf
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		RACRedefineSelf
		return [self subscribeNext:^(id x) {
			if(whereBlock(x)) {
				[observer sendNext:x];
			}
		} error:^(NSError *error) {
			[observer sendError:error];
		} completed:^{
			[observer sendCompleted];
		}];
	}];
}

- (instancetype)do:(void (^)(id x))block {
	NSParameterAssert(block != NULL);

	[self subscribeNext:block];
	return self;
}

- (instancetype)throttle:(NSTimeInterval)interval {	
	RACCreateWeakSelf
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		RACRedefineSelf
		__block id lastDelayedId = nil;
		return [self subscribeNext:^(id x) {
			lastDelayedId = [self performBlock:^{
				[observer sendNext:x];
			} afterDelay:interval];
		} error:^(NSError *error) {
			[self cancelPreviousPerformBlockRequestsWithId:lastDelayedId];
			[observer sendError:error];
		} completed:^{
			[observer sendCompleted];
		}];
	}];
}

- (instancetype)repeat {
	RACCreateWeakSelf
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		RACRedefineSelf
		__block RACObserver *innerObserver = [RACObserver observerWithNext:^(id x) {
			[observer sendNext:x];
		} error:^(NSError *error) {
			[observer sendError:error];
		} completed:^{
			[self subscribe:innerObserver];
		}];
		
		return [self subscribe:innerObserver];
	}];
}

- (instancetype)defer {
	RACCreateWeakSelf
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		RACRedefineSelf
		__block RACObserver *innerObserver = [RACObserver observerWithNext:^(id x) {
			[observer sendNext:x];
		} error:^(NSError *error) {
			[self subscribe:innerObserver];
		} completed:^{
			[observer sendCompleted];
		}];
		
		return [self subscribe:innerObserver];
	}];
}

- (instancetype)finally:(void (^)(void))block {
	NSParameterAssert(block != NULL);
	
	[self subscribeNext:^(id _) {
		
	} error:^(NSError *error) {
		block();
	} completed:^{
		block();
	}];
	
	return self;
}

- (instancetype)windowWithStart:(id<RACObservable>)openObservable close:(id<RACObservable> (^)(id<RACObservable> start))closeBlock {
	NSParameterAssert(openObservable != nil);
	NSParameterAssert(closeBlock != NULL);
	
	RACCreateWeakSelf
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		RACRedefineSelf
				
		__block RACSubject *currentWindow = nil;
		__block id<RACObservable> currentCloseWindow = nil;
		__block RACObservableDisposeBlock disposeCloseObserver = NULL;
		
		void (^closeCurrentWindow)(void) = ^{
			[currentWindow sendCompleted];
			currentWindow = nil;
			currentCloseWindow = nil;
			disposeCloseObserver();
			disposeCloseObserver = NULL;
		};
		
		RACObservableDisposeBlock disposeOpenObserver = [openObservable subscribe:[RACObserver observerWithNext:^(id x) {
			if(currentWindow == nil) {
				currentWindow = [RACSubject subject];
				[observer sendNext:currentWindow];
				
				currentCloseWindow = closeBlock(currentWindow);
				disposeCloseObserver = [currentCloseWindow subscribe:[RACObserver observerWithNext:^(id x) {
					closeCurrentWindow();
				} error:^(NSError *error) {
					closeCurrentWindow();
				} completed:^{
					closeCurrentWindow();
				}]];
			}
		} error:^(NSError *error) {
			
		} completed:^{
			
		}]];
		
		RACObservableDisposeBlock disposeSelfObserver = [self subscribeNext:^(id x) {
			[currentWindow sendNext:x];
		} error:^(NSError *error) {
			[observer sendError:error];
		} completed:^{
			[observer sendCompleted];
		}];
		
		return ^{
			if(disposeCloseObserver != NULL) disposeCloseObserver();
			disposeOpenObserver();
			disposeSelfObserver();
		};
	}];
}

- (instancetype)buffer:(NSUInteger)bufferCount {
	RACCreateWeakSelf
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		RACRedefineSelf
		RACBehaviorSubject *windowOpenSubject = [RACBehaviorSubject behaviorSubjectWithDefaultValue:@""];
		RACSubject *windowCloseSubject = [RACSubject subject];
		
		__block NSUInteger valuesReceived = 0;
		return [[self windowWithStart:windowOpenSubject close:^(id<RACObservable> start) {
			return windowCloseSubject;
		}] subscribeNext:^(id x) {		
			[x subscribeNext:^(id x) {
				valuesReceived++;
				if(valuesReceived % bufferCount == 0) {
					[windowCloseSubject sendNext:x];
					[windowOpenSubject sendNext:@""];
				}
			} error:^(NSError *error) {
				
			} completed:^{
				
			}];
		} error:^(NSError *error) {
			
		} completed:^{
			
		}];
	}];
}

@end
