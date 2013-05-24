//
//  NSObjectRACLiftingiOSSpec.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 23/05/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACLifting.h"
#import "NSObjectRACLiftingExamples.h"
#import "RACTestObject.h"
#import "RACSubject.h"
#import <UIKit/UIGeometry.h>

SpecBegin(NSObjectRACLiftingiOSSpec)

describe(@"-rac_liftSelector:withObjects:", ^{
	__block RACTestObject *object;
	
	beforeEach(^{
		object = [RACTestObject new];
	});
	
	itShouldBehaveLike(@"RACLifting", @{ RACLiftingTestRigName : RACLiftingSelectorTestRigName });
	
	it(@"should work for CGRect", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setRectValue:) withObjects:subject];
		
		expect(object.rectValue).to.equal(CGRectZero);
		
		CGRect value = CGRectMake(10, 20, 30, 40);
		[subject sendNext:[NSValue valueWithCGRect:value]];
		expect(object.rectValue).to.equal(value);
	});
	
	it(@"should work for CGSize", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setSizeValue:) withObjects:subject];
		
		expect(object.sizeValue).to.equal(CGSizeZero);
		
		CGSize value = CGSizeMake(10, 20);
		[subject sendNext:[NSValue valueWithCGSize:value]];
		expect(object.sizeValue).to.equal(value);
	});
	
	it(@"should work for CGPoint", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setPointValue:) withObjects:subject];
		
		expect(object.pointValue).to.equal(CGPointZero);
		
		CGPoint value = CGPointMake(10, 20);
		[subject sendNext:[NSValue valueWithCGPoint:value]];
		expect(object.pointValue).to.equal(value);
	});
	
});

describe(@"-rac_liftSelector:withObjectsFromArray:", ^{
	__block RACTestObject *object;
	
	beforeEach(^{
		object = [[RACTestObject alloc] init];
	});
	
	it(@"should work for CGRect", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setRectValue:) withObjectsFromArray:@[ subject ]];
		
		expect(object.rectValue).to.equal(CGRectZero);
		
		CGRect value = CGRectMake(10, 20, 30, 40);
		[subject sendNext:[NSValue valueWithCGRect:value]];
		expect(object.rectValue).to.equal(value);
	});
	
	it(@"should work for CGSize", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setSizeValue:) withObjectsFromArray:@[ subject ]];
		
		expect(object.sizeValue).to.equal(CGSizeZero);
		
		CGSize value = CGSizeMake(10, 20);
		[subject sendNext:[NSValue valueWithCGSize:value]];
		expect(object.sizeValue).to.equal(value);
	});
	
	it(@"should work for CGPoint", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setPointValue:) withObjectsFromArray:@[ subject ]];
		
		expect(object.pointValue).to.equal(CGPointZero);
		
		CGPoint value = CGPointMake(10, 20);
		[subject sendNext:[NSValue valueWithCGPoint:value]];
		expect(object.pointValue).to.equal(value);
	});
	
});

SpecEnd
