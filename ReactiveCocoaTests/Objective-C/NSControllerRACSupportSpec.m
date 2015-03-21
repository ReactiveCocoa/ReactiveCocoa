//
//  NSControllerRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 26/10/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import <AppKit/AppKit.h>
#import "RACKVOChannel.h"

@interface RACTestController : NSController

@property (nonatomic, strong) id object;

@end

@implementation RACTestController

@end

QuickSpecBegin(NSControllerRACSupportSpec)

qck_it(@"RACKVOChannel should support NSController", ^{
	RACTestController *a = [[RACTestController alloc] init];
	RACTestController *b = [[RACTestController alloc] init];
	RACChannelTo(a, object) = RACChannelTo(b, object);
	expect(a.object).to(beNil());
	expect(b.object).to(beNil());

	a.object = a;
	expect(a.object).to(equal(a));
	expect(b.object).to(equal(a));

	b.object = b;
	expect(a.object).to(equal(b));
	expect(b.object).to(equal(b));

	a.object = nil;
	expect(a.object).to(beNil());
	expect(b.object).to(beNil());
});

QuickSpecEnd
