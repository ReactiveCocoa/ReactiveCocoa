//
//  NSUserDefaultsRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Matt Diephouse on 12/19/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSUserDefaults+RACSupport.h"

#import "RACKVOChannel.h"

static NSString * const NSUserDefaultsRACSupportSpecStringDefault = @"NSUserDefaultsRACSupportSpecStringDefault";
static NSString * const NSUserDefaultsRACSupportSpecBoolDefault = @"NSUserDefaultsRACSupportSpecBoolDefault";

static void * TestContext = &TestContext;

@interface TestObserver : NSObject

@property (strong, atomic) NSString *string1;
@property (strong, atomic) NSString *string2;

@property (assign, atomic) BOOL bool1;

@end

@implementation TestObserver

@end

SpecBegin(NSUserDefaultsRACSupportSpec)

__block NSUserDefaults *defaults = nil;
__block TestObserver *observer = nil;

beforeAll(^{
	defaults = NSUserDefaults.standardUserDefaults;
});

beforeEach(^{
	[defaults removeObjectForKey:NSUserDefaultsRACSupportSpecStringDefault];
	[defaults removeObjectForKey:NSUserDefaultsRACSupportSpecBoolDefault];
	
	observer = [TestObserver new];
});

afterEach(^{
	observer = nil;
});

it(@"should set defaults", ^{
	RACChannelTo(observer, string1) = [defaults rac_channelTerminalForKey:NSUserDefaultsRACSupportSpecStringDefault];
	RACChannelTo(observer, bool1, @NO) = [defaults rac_channelTerminalForKey:NSUserDefaultsRACSupportSpecBoolDefault];
	
	observer.string1 = @"A string";
	observer.bool1 = YES;
	
	expect([defaults objectForKey:NSUserDefaultsRACSupportSpecStringDefault]).to.equal(@"A string");
	expect([defaults objectForKey:NSUserDefaultsRACSupportSpecBoolDefault]).to.equal(@YES);
});

it(@"should read defaults", ^{
	RACChannelTo(observer, string1) = [defaults rac_channelTerminalForKey:NSUserDefaultsRACSupportSpecStringDefault];
	RACChannelTo(observer, bool1, @NO) = [defaults rac_channelTerminalForKey:NSUserDefaultsRACSupportSpecBoolDefault];
	
	expect(observer.string1).to.beNil();
	expect(observer.bool1).to.equal(@NO);
	
	[defaults setObject:@"Another string" forKey:NSUserDefaultsRACSupportSpecStringDefault];
	[defaults setBool:YES forKey:NSUserDefaultsRACSupportSpecBoolDefault];
	
	expect(observer.string1).to.equal(@"Another string");
	expect(observer.bool1).to.equal(@YES);
});

it(@"should be okay to create 2 terminals", ^{
	RACChannelTo(observer, string1) = [defaults rac_channelTerminalForKey:NSUserDefaultsRACSupportSpecStringDefault];
	RACChannelTo(observer, string2) = [defaults rac_channelTerminalForKey:NSUserDefaultsRACSupportSpecStringDefault];
	
	[defaults setObject:@"String 3" forKey:NSUserDefaultsRACSupportSpecStringDefault];
	
	expect(observer.string1).to.equal(@"String 3");
	expect(observer.string2).to.equal(@"String 3");
});

it(@"should handle removed defaults", ^{
	observer.string1 = @"Some string";
	observer.bool1 = YES;
	
	RACChannelTo(observer, string1) = [defaults rac_channelTerminalForKey:NSUserDefaultsRACSupportSpecStringDefault];
	RACChannelTo(observer, bool1, @NO) = [defaults rac_channelTerminalForKey:NSUserDefaultsRACSupportSpecBoolDefault];
	
	[defaults removeObjectForKey:NSUserDefaultsRACSupportSpecStringDefault];
	[defaults removeObjectForKey:NSUserDefaultsRACSupportSpecBoolDefault];
	
	expect(observer.string1).to.beNil();
	expect(observer.bool1).to.equal(@NO);
});

SpecEnd
