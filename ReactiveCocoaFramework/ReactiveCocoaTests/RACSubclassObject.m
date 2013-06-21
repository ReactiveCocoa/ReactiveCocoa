//
//  RACSubclassObject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/18/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSubclassObject.h"
#import "RACScheduler.h"

@implementation RACSubclassObject

- (NSString *)combineObjectValue:(id)objectValue andIntegerValue:(NSInteger)integerValue {
	NSString *appended = [[objectValue description] stringByAppendingString:@"SUBCLASS"];
	return [super combineObjectValue:appended andIntegerValue:integerValue];
}

- (void)setObjectValue:(id)objectValue andSecondObjectValue:(id)secondObjectValue {
	[RACScheduler.currentScheduler schedule:^{
		[super setObjectValue:objectValue andSecondObjectValue:secondObjectValue];
	}];
}

@end
