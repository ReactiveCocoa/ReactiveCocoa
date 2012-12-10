//
//  NSObjectRACPropertySubscribingSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/28/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACPropertySubscribing.h"
#import "RACDisposable.h"
#import "RACTestObject.h"
#import "RACSignal.h"

SpecBegin(NSObjectRACPropertySubscribing)

describe(@"-rac_addDeallocDisposable:", ^{
	it(@"should dispose of the disposable when it is dealloc'd", ^{
		__block BOOL wasDisposed = NO;
		@autoreleasepool {
			NSObject *object __attribute__((objc_precise_lifetime)) = [[NSObject alloc] init];
			[object rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				wasDisposed = YES;
			}]];

			expect(wasDisposed).to.beFalsy();
		}

		expect(wasDisposed).to.beTruthy();
	});
});

describe(@"+rac_signalFor:keyPath:onObject:", ^{
	it(@"shouldn't crash when the value is changed on a different queue", ^{
		__block id value;
		@autoreleasepool {
			RACTestObject *object __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			id<RACSignal> signal = [NSObject rac_signalFor:object keyPath:@"objectValue" onObject:self];
			[signal subscribeNext:^(id x) {
				value = x;
			}];

			NSOperationQueue *queue = [[NSOperationQueue alloc] init];
			[queue addOperationWithBlock:^{
				object.objectValue = @1;
			}];

			[queue waitUntilAllOperationsAreFinished];
		}

		expect(value).will.equal(@1);
	});
});

SpecEnd
