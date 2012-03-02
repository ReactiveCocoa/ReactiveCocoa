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
@property (nonatomic, strong) RACObservableSequence *textFieldValues;
@property (nonatomic, assign) BOOL isMagic;
@property (nonatomic, copy) NSString *textFieldValue;
@end


@implementation RACAppDelegate


#pragma mark NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	// UI elements should *always* be backed by the model.
	[self.doMagicButton bind:@"enabled" toObject:self withKeyPath:@"isMagic" options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
	[self.textField bind:@"value" toObject:self withKeyPath:@"textFieldValue" options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
	
	// We can then observe the sequence of values that our model receives.
	self.textFieldValues = [self observableSequenceForKeyPath:@"textFieldValue"];
	
	[[[self.textFieldValues 
	   where:^BOOL(id x) { 
		return [[x lowercaseString] rangeOfString:@"upper"].length > 0; 
	}] select:^(id x) { 
		return [x uppercaseString];
	}] subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id x) {
		[self.textField setStringValue:x];
	}]];
	
	[[self.textFieldValues 
	  select:^(id x) {
		  return [NSNumber numberWithBool:[x hasPrefix:@"magic"]];
	}] subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id x) {
		self.isMagic = [x boolValue];
	}]];
	
	[[[self.textFieldValues 
	   select:^(id x) {
		return x;
	}] throttle:1.0f] 
	 subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id x) {
		NSLog(@"delayed: %@", x);
	}]];
}


#pragma mark API

@synthesize window;
@synthesize textField;
@synthesize textFieldValues;
@synthesize doMagicButton;
@synthesize isMagic;
@synthesize textFieldValue;

@end
