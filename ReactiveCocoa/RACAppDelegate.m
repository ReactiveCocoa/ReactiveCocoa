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

@interface RACAppDelegate ()
@property (nonatomic, strong) RACObservableSequence *textField1Values;
@property (nonatomic, copy) NSString *textField1Value;
@property (nonatomic, assign) BOOL isMagic;
@end


@implementation RACAppDelegate


#pragma mark NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	// UI elements should *always* be backed by the model.
	[self.doMagicButton bind:@"enabled" toObject:self withKeyPath:@"isMagic" options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
	[self.textField1 bind:@"value" toObject:self withKeyPath:@"textField1Value" options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
	
	// We can then observe the sequence of values that our model receives.
	self.textField1Values = RACObservableSequenceForProperty(self.textField1Value);
	
	[[[[self.textField1Values 
		select:^(id x) {
		return [x lowercaseString];
	}] where:^BOOL(id x) { 
		return [x rangeOfString:@"upper"].length > 0; 
	}] select:^(id x) { 
		return [x uppercaseString];
	}] subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id x) {
		self.textField1Value = x;
	}]];
	
	[[self.textField1Values 
	  select:^(id x) {
		  return [NSNumber numberWithBool:[x hasPrefix:@"magic"]];
	}] subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id x) {
		self.isMagic = [x boolValue];
	}]];
	
	[[[self.textField1Values 
	   select:^(id x) {
		return x;
	}] throttle:1.0f] 
	 subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id x) {
		NSLog(@"delayed: %@", x);
	}]];
}


#pragma mark API

@synthesize window;
@synthesize textField1;
@synthesize textField1Values;
@synthesize doMagicButton;
@synthesize isMagic;
@synthesize textField1Value;
@synthesize textField2;
@synthesize matchesLabel;
	 
@end
