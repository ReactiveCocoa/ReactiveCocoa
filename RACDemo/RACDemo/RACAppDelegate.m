//
//  RACAppDelegate.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACAppDelegate.h"
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface RACAppDelegate ()
@property (nonatomic, strong) RACValue *textField1Value;
@property (nonatomic, strong) RACValue *textFieldsDoNotMatchValue;
@property (nonatomic, strong) RACValue *textField2Value;
@end


@implementation RACAppDelegate


#pragma mark NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	// UI elements should *always* be backed by the model.
	[self.textField1 bind:NSValueBinding toValue:self.textField1Value];
	[self.matchesLabel bind:NSHiddenBinding toValue:self.textFieldsDoNotMatchValue];
	[self.textField2 bind:NSValueBinding toValue:self.textField2Value];
	
	RACCommand *loginCommand = [RACCommand command];
	loginCommand.canExecuteValue = [RACValue valueWithValue:[NSNumber numberWithBool:NO]];
	[loginCommand 
		subscribeNext:^(id _) { NSLog(@"clicked!"); }];
	
	[[[loginCommand 
		select:^(id _) { return self.textField1Value.value;	}]
		where:^(id x) { return [x isEqualToString:@"magic!"]; }] 
		subscribeNext:^(id _) { NSLog(@"even more magic!"); }];
	
	[[[[loginCommand 
		select:^(id _) { return self.textField1Value.value;	}]
		where:^(id x) { return [x isEqualToString:@"magic!"]; }] 
		selectMany:^(id _) { return self.textField1Value; }]
		subscribeNext:^(id x) { NSLog(@"most magic! %@", x); }];
	
	[[self.textField1Value 
		select:^(id x) { return [NSNumber numberWithBool:[x hasPrefix:@"magic"]]; }] 
		toProperty:loginCommand.canExecuteValue];
	
	[[loginCommand 
		take:2] 
		subscribeNext:^(id _) { NSLog(@"double-click!"); }];
	
	[self.doMagicButton addCommand:loginCommand];
	
	RACCommand *duplicateCommand = [RACCommand command];
	duplicateCommand.canExecuteValue = [RACValue valueWithValue:[NSNumber numberWithBool:NO]];
	[[self.textField1Value 
		select:^(id x) { return [NSNumber numberWithBool:[x length] > 0]; }] 
		toProperty:duplicateCommand.canExecuteValue];
	
	[duplicateCommand 
		subscribeNext:^(id _) { self.textField2Value.value = self.textField1Value.value; }];
	
	[self.duplicateButton addCommand:duplicateCommand];
	
	[[[RACValue 
		combineLatest:[NSArray arrayWithObjects:self.textField1Value, self.textField2Value, nil]] 
		select:^(NSArray *x) { return [NSNumber numberWithBool:![[x objectAtIndex:0] isEqualToString:[x objectAtIndex:1]]]; }]
		toProperty:self.textFieldsDoNotMatchValue];
	
	[[[[RACValue 
		merge:[NSArray arrayWithObjects:self.textField1Value, self.textField2Value, nil]] 
		throttle:1.0f] 
		distinctUntilChanged]
		subscribeNext:^(id x) { NSLog(@"delayed: %@", x); }];
}


#pragma mark API

@synthesize window;
@synthesize textField1;
@synthesize doMagicButton;
@synthesize textField2;
@synthesize matchesLabel;
@synthesize duplicateButton;
rac_synthesize_val(textField1Value, @"");
rac_synthesize_val(textFieldsDoNotMatchValue, [NSNumber numberWithBool:YES]);
rac_synthesize_val(textField2Value, @"");
	 
@end
