//
//  RACCommand.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACCommand.h"


@implementation RACCommand


#pragma mark API

@synthesize canExecute;

+ (RACCommand *)command {
	return [self value];
}

- (RACObservableValue *)canExecute {
	if(canExecute == nil) {
		canExecute = [RACObservableValue value];
	}
	
	return canExecute;
}

- (BOOL)canCurrentlyExecute {
	return [self.canExecute.value boolValue];
}

- (void)execute:(id)sender {
	if(!self.canCurrentlyExecute) return;
	
	self.value = sender;
}

@end
