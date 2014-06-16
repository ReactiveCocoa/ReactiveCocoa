//
//  RACControlActionExamples.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-08-15.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACControlActionExamples.h"

#import "RACAction.h"
#import "RACDynamicSignalGenerator.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"

NSString * const RACControlActionExamples = @"RACControlActionExamples";
NSString * const RACControlActionExampleControl = @"RACControlActionExampleControl";
NSString * const RACControlActionExampleActivateBlock = @"RACControlActionExampleActivateBlock";

// Methods used by the unit test that would otherwise require platform-specific
// imports.
@interface NSObject (RACControlActionExamples)

@property (nonatomic, strong) RACAction *rac_action;

- (BOOL)isEnabled;

@end

SharedExampleGroupsBegin(RACControlActionExamples)

sharedExamplesFor(RACControlActionExamples, ^(NSDictionary *data) {
	__block id control;
	__block void (^activate)(id);

	__block RACSubject *enabledSubject;
	__block RACAction *action;
	__block BOOL executed;

	beforeEach(^{
		control = data[RACControlActionExampleControl];
		activate = [data[RACControlActionExampleActivateBlock] copy];

		enabledSubject = [RACSubject subject];
		executed = NO;

		action = [[RACDynamicSignalGenerator
			generatorWithBlock:^(id sender) {
				expect(sender).to.beIdenticalTo(control);

				return [RACSignal defer:^{
					executed = YES;
					return [RACSignal return:sender];
				}];
			}]
			actionEnabledIf:enabledSubject];

		[control setRac_action:action];
		expect(executed).to.beFalsy();
	});

	it(@"should bind the control's enabledness to the action", ^{
		expect([control isEnabled]).will.beTruthy();

		[enabledSubject sendNext:@NO];
		expect([control isEnabled]).will.beFalsy();
		
		[enabledSubject sendNext:@YES];
		expect([control isEnabled]).will.beTruthy();
	});

	it(@"should execute the control's action when activated", ^{
		activate(control);
		expect(executed).will.beTruthy();
	});
	
	it(@"should overwrite an existing action when setting a new one", ^{
		RACAction *secondAction = [[RACSignal empty] action];
		
		[control setRac_action:secondAction];
		expect([control rac_action]).to.beIdenticalTo(secondAction);
	});
});

SharedExampleGroupsEnd
