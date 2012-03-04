//
//  RACAppDelegate.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACAppDelegate.h"
#import "RACObserver.h"
#import "NSObject+RACPropertyObserving.h"
#import "RACObservableValue.h"
#import "RACCommand.h"
#import "NSButton+RACCommandSupport.h"

@interface RACAppDelegate ()
@property (nonatomic, strong) RACObservableValue *textField1Value;
@property (nonatomic, strong) RACObservableValue *textFieldsDoNotMatchValue;
@property (nonatomic, strong) RACObservableValue *textField2Value;
@end


@implementation RACAppDelegate


#pragma mark NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	// UI elements should *always* be backed by the model.
	[self.textField1 bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.textField1Value.value)];
	[self.matchesLabel bind:NSHiddenBinding toObject:self withKeyPath:RACKVO(self.textFieldsDoNotMatchValue.value)];
	[self.textField2 bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.textField2Value.value)];
	
	RACCommand *loginCommand = [RACCommand command];
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
		toProperty:loginCommand.canExecute];
	
	[[loginCommand 
		take:2] 
		subscribeNext:^(id _) { NSLog(@"double-click!"); }];
	
	[self.doMagicButton addCommand:loginCommand];
	
	RACCommand *duplicateCommand = [RACCommand command];

	[[self.textField1Value 
		select:^(id x) { return [NSNumber numberWithBool:[x length] > 0]; }] 
		toProperty:duplicateCommand.canExecute];
	
	[duplicateCommand 
		subscribeNext:^(id _) { self.textField2Value.value = self.textField1Value.value; }];
	
	[self.duplicateButton addCommand:duplicateCommand];
	
	[[[RACObservableValue 
		combineLatest:[NSArray arrayWithObjects:self.textField1Value, self.textField2Value, nil]] 
		select:^(NSArray *x) { return [NSNumber numberWithBool:![[x objectAtIndex:0] isEqualToString:[x objectAtIndex:1]]]; }]
		toProperty:self.textFieldsDoNotMatchValue];
	
	[[[[RACObservableValue 
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
