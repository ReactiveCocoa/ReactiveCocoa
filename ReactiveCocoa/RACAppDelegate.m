//
//  RACAppDelegate.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACAppDelegate.h"
#import "RACObservableSequence.h"
#import "RACObserver.h"
#import "NSObject+RACPropertyObserving.h"
#import "RACObservableValue.h"

@interface RACAppDelegate ()
@property (nonatomic, strong) RACObservableValue *textField1Value;
@property (nonatomic, strong) RACObservableValue *isMagicValue;
@property (nonatomic, strong) RACObservableValue *doMatchObservable;
@property (nonatomic, strong) RACObservableValue *textField2Value;
@end


@implementation RACAppDelegate


#pragma mark NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	self.textField1Value = [RACObservableValue valueWithValue:@""];
	self.textField2Value = [RACObservableValue valueWithValue:@""];
	self.isMagicValue = [RACObservableValue valueWithValue:[NSNumber numberWithBool:NO]];
	self.doMatchObservable = [RACObservableValue valueWithValue:[NSNumber numberWithBool:YES]];
	
	// UI elements should *always* be backed by the model.
	[self.doMagicButton bind:NSEnabledBinding toObject:self withKeyPath:RACKVO(self.isMagicValue.value)];
	[self.textField1 bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.textField1Value.value)];
	[self.matchesLabel bind:NSHiddenBinding toObject:self withKeyPath:RACKVO(self.doMatchObservable.value)];
	[self.textField2 bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.textField2Value.value)];
	
	[[[self.doMatchObservable 
	   whenAny:self.textField1Value, self.textField2Value, nil] 
	  select:^(id value) { return [NSNumber numberWithBool:![self.textField1Value.value isEqualToString:self.textField2Value.value]]; }] 
	 toProperty:self.doMatchObservable];
	
	[[self.textField1Value 
	  select:^(id x) { return [NSNumber numberWithBool:[x hasPrefix:@"magic"]]; }] 
	 toProperty:self.isMagicValue];
	
	[[self.textField1Value 
	  throttle:1.0f] 
	 subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id x) {
		NSLog(@"delayed: %@", x);
	}]];
}


#pragma mark API

@synthesize window;
@synthesize textField1;
@synthesize doMagicButton;
@synthesize isMagicValue;
@synthesize textField1Value;
@synthesize textField2;
@synthesize matchesLabel;
@synthesize doMatchObservable;
@synthesize textField2Value;
	 
@end
