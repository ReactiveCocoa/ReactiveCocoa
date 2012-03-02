//
//  RACAppDelegate.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACAppDelegate.h"
#import "RACObservableArray.h"
#import "RACObserver.h"
#import "NSObject+RACPropertyObserving.h"

@interface RACAppDelegate ()
@property (nonatomic, strong) id<RACObservable> textFieldValueObserver;
@property (nonatomic, assign) BOOL isMagic;
@end


@implementation RACAppDelegate


#pragma mark NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	[self.doMagicButton bind:@"enabled" toObject:self withKeyPath:@"isMagic" options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
	
	self.textFieldValueObserver = [self.textField observableForBinding:@"value"];
	
	[[[self.textFieldValueObserver 
	   where:^BOOL(id x) {
		return [[x lowercaseString] rangeOfString:@"upper"].length > 0;
	}] select:^(id x) {
		return [x uppercaseString];
	}] subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id x) {
		[self.textField setStringValue:x];
	}]];
	
	[[self.textFieldValueObserver 
	  select:^(id x) {
		  return [NSNumber numberWithBool:[x hasPrefix:@"magic"]];
	}] subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id x) {
		self.isMagic = [x boolValue];
	}]];
	
	[[[self.textFieldValueObserver 
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
@synthesize textFieldValueObserver;
@synthesize doMagicButton;
@synthesize isMagic;

@end
