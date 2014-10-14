//
//  NSObject+RACDeallocating.m
//  ReactiveCocoa
//
//  Created by Kazuo Koga on 2013/03/15.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACTestObject.h"

#import "NSObject+RACDeallocating.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSignal+Operations.h"
#import <objc/runtime.h>

@interface RACDeallocSwizzlingTestClass : NSObject
@end

@implementation RACDeallocSwizzlingTestClass

- (void)dealloc {
	// Provide an empty implementation just so we can swizzle it.
}

@end

@interface RACDeallocSwizzlingTestSubclass : RACDeallocSwizzlingTestClass
@end

@implementation RACDeallocSwizzlingTestSubclass
@end

QuickSpecBegin(NSObjectRACDeallocatingSpec)

qck_describe(@"-dealloc swizzling", ^{
	SEL selector = NSSelectorFromString(@"dealloc");

	qck_it(@"should not invoke superclass -dealloc method twice", ^{
		__block NSUInteger superclassDeallocatedCount = 0;
		__block BOOL subclassDeallocated = NO;

		@autoreleasepool {
			RACDeallocSwizzlingTestSubclass *object __attribute__((objc_precise_lifetime)) = [[RACDeallocSwizzlingTestSubclass alloc] init];

			Method oldDeallocMethod = class_getInstanceMethod(RACDeallocSwizzlingTestClass.class, selector);
			void (*oldDealloc)(id, SEL) = (__typeof__(oldDealloc))method_getImplementation(oldDeallocMethod);

			id newDealloc = ^(__unsafe_unretained id self) {
				superclassDeallocatedCount++;
				oldDealloc(self, selector);
			};

			class_replaceMethod(RACDeallocSwizzlingTestClass.class, selector, imp_implementationWithBlock(newDealloc), method_getTypeEncoding(oldDeallocMethod));

			[object.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				subclassDeallocated = YES;
			}]];

			expect(@(subclassDeallocated)).to(beFalsy());
			expect(@(superclassDeallocatedCount)).to(equal(@0));
		}

		expect(@(subclassDeallocated)).to(beTruthy());
		expect(@(superclassDeallocatedCount)).to(equal(@1));
	});

	qck_it(@"should invoke superclass -dealloc method swizzled in after the subclass", ^{
		__block BOOL superclassDeallocated = NO;
		__block BOOL subclassDeallocated = NO;

		@autoreleasepool {
			RACDeallocSwizzlingTestSubclass *object __attribute__((objc_precise_lifetime)) = [[RACDeallocSwizzlingTestSubclass alloc] init];
			[object.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				subclassDeallocated = YES;
			}]];

			Method oldDeallocMethod = class_getInstanceMethod(RACDeallocSwizzlingTestClass.class, selector);
			void (*oldDealloc)(id, SEL) = (__typeof__(oldDealloc))method_getImplementation(oldDeallocMethod);

			id newDealloc = ^(__unsafe_unretained id self) {
				superclassDeallocated = YES;
				oldDealloc(self, selector);
			};

			class_replaceMethod(RACDeallocSwizzlingTestClass.class, selector, imp_implementationWithBlock(newDealloc), method_getTypeEncoding(oldDeallocMethod));

			expect(@(subclassDeallocated)).to(beFalsy());
			expect(@(superclassDeallocated)).to(beFalsy());
		}

		expect(@(subclassDeallocated)).to(beTruthy());
		expect(@(superclassDeallocated)).to(beTruthy());
	});
});

qck_describe(@"-rac_deallocDisposable", ^{
	qck_it(@"should dispose of the disposable when it is dealloc'd", ^{
		__block BOOL wasDisposed = NO;
		@autoreleasepool {
			NSObject *object __attribute__((objc_precise_lifetime)) = [[NSObject alloc] init];
			[object.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				wasDisposed = YES;
			}]];

			expect(@(wasDisposed)).to(beFalsy());
		}

		expect(@(wasDisposed)).to(beTruthy());
	});

	qck_it(@"should be able to use the object during disposal", ^{
		@autoreleasepool {
			RACTestObject *object __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];

			@autoreleasepool {
				object.objectValue = [@"foo" mutableCopy];
			}

			__unsafe_unretained RACTestObject *weakObject = object;

			[object.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				expect(weakObject.objectValue).to(equal(@"foo"));
			}]];
		}
	});
});

qck_describe(@"-rac_willDeallocSignal", ^{
	qck_it(@"should complete on dealloc", ^{
		__block BOOL completed = NO;
		@autoreleasepool {
			[[[[RACTestObject alloc] init] rac_willDeallocSignal] subscribeCompleted:^{
				completed = YES;
			}];
		}

		expect(@(completed)).to(beTruthy());
	});

	qck_it(@"should not send anything", ^{
		__block BOOL valueReceived = NO;
		__block BOOL completed = NO;
		@autoreleasepool {
			[[[[RACTestObject alloc] init] rac_willDeallocSignal] subscribeNext:^(id x) {
				valueReceived = YES;
			} completed:^{
				completed = YES;
			}];
		}

		expect(@(valueReceived)).to(beFalsy());
		expect(@(completed)).to(beTruthy());
	});

	qck_it(@"should complete upon subscription if already deallocated", ^{
		__block BOOL deallocated = NO;

		RACSignal *signal;

		@autoreleasepool {
			RACTestObject *object = [[RACTestObject alloc] init];

			signal = [object rac_willDeallocSignal];
			[signal subscribeCompleted:^{
				deallocated = YES;
			}];
		}

		expect(@(deallocated)).to(beTruthy());
		expect(@([signal waitUntilCompleted:NULL])).to(beTruthy());
	});

	qck_it(@"should complete before the object is invalid", ^{
		__block NSString *objectValue;

		@autoreleasepool {
			RACTestObject *object __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];

			@autoreleasepool {
				object.objectValue = [@"foo" mutableCopy];
			}

			__unsafe_unretained RACTestObject *weakObject = object;

			[[object rac_willDeallocSignal] subscribeCompleted:^{
				objectValue = [weakObject.objectValue copy];
			}];
		}

		expect(objectValue).to(equal(@"foo"));
	});
});

QuickSpecEnd
