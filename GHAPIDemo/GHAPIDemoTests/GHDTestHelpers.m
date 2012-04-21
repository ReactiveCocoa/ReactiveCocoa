//
//  GHDTestHelpers.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/6/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "GHDTestHelpers.h"

void GHDRunRunLoop(void) {
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1f]];
}

extern void GHDRunRunLoopWhile(BOOL (^conditionBlock)(void)) {
	while(conditionBlock()) {
		GHDRunRunLoop();
	}
}
