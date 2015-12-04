//
//  RACTestUIButton.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-06-15.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACTestUIButton.h"

@implementation RACTestUIButton

+ (instancetype)button {
	RACTestUIButton *button = [self buttonWithType:UIButtonTypeCustom];
	return button;
}

// Required for unit testing – controls don't work normally
// outside of normal apps. 
-(void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
	[target performSelector:action withObject:self];
#pragma clang diagnostic pop
}

@end
