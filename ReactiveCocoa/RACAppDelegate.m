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
		subscribeNext:^(id x) { NSLog(@"clicked!"); }];
	
	[[[loginCommand 
		select:^(id x) { return self.textField1Value.value;	}]
		where:^(id x) { return [x isEqualToString:@"magic!"]; }] 
		subscribeNext:^(id x) { NSLog(@"even more magic!"); }];
	
	[[self.textField1Value 
		select:^(id x) { return [NSNumber numberWithBool:[x hasPrefix:@"magic"]]; }] 
		toProperty:loginCommand.canExecute];
	
	[self.doMagicButton addCommand:loginCommand];
	
	[[RACObservableValue 
		whenAny:[NSArray arrayWithObjects:self.textField1Value, self.textField2Value, nil] 
		reduce:^(NSArray *x) { return [NSNumber numberWithBool:![[x objectAtIndex:0] isEqualToString:[x objectAtIndex:1]]]; }]
		toProperty:self.textFieldsDoNotMatchValue];
	
	[[[RACObservableValue 
		merge:[NSArray arrayWithObjects:self.textField1Value, self.textField2Value, nil]] 
		throttle:1.0f] 
		subscribeNext:^(id x) { NSLog(@"delayed: %@", x); }];
}


#pragma mark API

@synthesize window;
@synthesize textField1;
@synthesize doMagicButton;
@synthesize textField2;
@synthesize matchesLabel;
rac_synthesize_val(textField1Value, @"");
rac_synthesize_val(textFieldsDoNotMatchValue, [NSNumber numberWithBool:YES]);
rac_synthesize_val(textField2Value, @"");
	 
@end
