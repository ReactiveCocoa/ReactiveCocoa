//
//  NSUserDefaultsRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Matt Diephouse on 12/19/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSUserDefaults+RACSupport.h"

#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "NSObject+RACDeallocating.h"
#import "RACSignal+Operations.h"

static NSString * const NSUserDefaultsRACSupportSpecStringDefault = @"NSUserDefaultsRACSupportSpecStringDefault";
static NSString * const NSUserDefaultsRACSupportSpecBoolDefault = @"NSUserDefaultsRACSupportSpecBoolDefault";

SpecBegin(NSUserDefaultsRACSupportSpec)

__block NSUserDefaults *defaults = nil;
__block NSString *string;
__block BOOL boolean;

beforeEach(^{
	defaults = NSUserDefaults.standardUserDefaults;
	[defaults removeObjectForKey:NSUserDefaultsRACSupportSpecStringDefault];
	[defaults removeObjectForKey:NSUserDefaultsRACSupportSpecBoolDefault];

	[[defaults rac_objectsForKey:NSUserDefaultsRACSupportSpecStringDefault] subscribeNext:^(NSString *x) {
		string = x;
	}];

	[[defaults rac_objectsForKey:NSUserDefaultsRACSupportSpecBoolDefault] subscribeNext:^(NSNumber *x) {
		boolean = x.boolValue;
	}];
	
	expect(string).to.beNil();
	expect(boolean).to.beFalsy();
});

it(@"should observe defaults", ^{
	[defaults setObject:@"Another string" forKey:NSUserDefaultsRACSupportSpecStringDefault];
	[defaults setBool:YES forKey:NSUserDefaultsRACSupportSpecBoolDefault];
	
	expect(string).to.equal(@"Another string");
	expect(boolean).to.beTruthy();

	[defaults removeObjectForKey:NSUserDefaultsRACSupportSpecStringDefault];
	[defaults removeObjectForKey:NSUserDefaultsRACSupportSpecBoolDefault];
	
	expect(string).to.beNil();
	expect(boolean).to.beFalsy();
});

it(@"shouldn't resend values", ^{
	__block NSUInteger nextCount = 0;
	[[defaults rac_objectsForKey:NSUserDefaultsRACSupportSpecStringDefault] subscribeNext:^(id _) {
		nextCount++;
	}];

	[defaults setObject:@"foobar" forKey:NSUserDefaultsRACSupportSpecStringDefault];
	expect(nextCount).to.equal(1);

	[defaults setObject:@"foobar" forKey:NSUserDefaultsRACSupportSpecStringDefault];
	expect(nextCount).to.equal(1);

	[defaults setObject:@"fuzzbuzz" forKey:NSUserDefaultsRACSupportSpecStringDefault];
	expect(nextCount).to.equal(2);
});

it(@"should complete when the NSUserDefaults deallocates", ^{
	__block BOOL completed = NO;
	__block BOOL deallocated = NO;
	
	@autoreleasepool {
		NSUserDefaults *customDefaults __attribute__((objc_precise_lifetime)) = [NSUserDefaults new];
		[customDefaults.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
			deallocated = YES;
		}]];
		
		[[customDefaults rac_objectsForKey:NSUserDefaultsRACSupportSpecStringDefault] subscribeCompleted:^{
			completed = YES;
		}];
	}
	
	expect(deallocated).to.beTruthy();
	expect(completed).to.beTruthy();
});

it(@"should send an initial value", ^{
	[defaults setObject:@"Initial" forKey:NSUserDefaultsRACSupportSpecStringDefault];
	expect([[defaults rac_objectsForKey:NSUserDefaultsRACSupportSpecStringDefault] first]).to.equal(@"Initial");
});

SpecEnd
