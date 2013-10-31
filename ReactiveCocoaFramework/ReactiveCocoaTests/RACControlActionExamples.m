//
//  RACControlActionExamples.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-08-15.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACControlActionExamples.h"

#import "RACAction.h"
#import "RACUnit.h"

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
	__block NSObject *control;
	__block void (^activate)(id);

	__block BOOL executed = NO;
	__block RACAction *action;

	beforeEach(^{
		control = data[RACControlActionExampleControl];
		activate = [data[RACControlActionExampleActivateBlock] copy];

		executed = NO;
		action = [RACAction actionWithBlock:^(NSError **error) {
			executed = YES;
			return YES;
		}];

		control.rac_action = action;
		expect(control.rac_action).to.beIdenticalTo(action);

		expect(executed).to.beFalsy();
	});

	it(@"should execute the control's action when activated", ^{
		activate(control);
		expect(executed).will.beTruthy();
	});
	
	it(@"should overwrite an existing action when setting a new one", ^{
		__block BOOL secondExecuted = NO;
		RACAction *secondAction = [RACAction actionWithBlock:^(NSError **error) {
			secondExecuted = YES;
			return YES;
		}];
		
		control.rac_action = secondAction;
		expect(control.rac_action).to.beIdenticalTo(secondAction);

		activate(control);
		expect(secondExecuted).will.beTruthy();
		expect(executed).to.beFalsy();
	});
});

SharedExampleGroupsEnd
