//
//  RACUnit.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/27/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACUnit.h"


@implementation RACUnit


#pragma mark API

+ (RACUnit *)defaultUnit {
	static dispatch_once_t onceToken;
	static RACUnit *defaultUnit = nil;
	dispatch_once(&onceToken, ^{
		defaultUnit = [[self alloc] init];
	});
	
	return defaultUnit;
}

@end
