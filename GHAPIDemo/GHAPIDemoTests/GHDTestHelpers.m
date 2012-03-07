//
//  GHDTestHelpers.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "GHDTestHelpers.h"

void GHDRunRunLoop(void) {
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1f]];
}

void GHDRunRunLoopUntil(BOOL condition) {
	while(!condition) {
		GHDRunRunLoop();
	}
}
