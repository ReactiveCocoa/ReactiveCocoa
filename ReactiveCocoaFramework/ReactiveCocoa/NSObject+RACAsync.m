//
//  NSObject+RACAsync.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/9/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NSObject+RACAsync.h"
#import "RACSequence.h"
#import "RACSequence+Private.h"


@implementation NSObject (RACAsync)

+ (RACSequence *)RACAsync:(id (^)(void))block {
	RACSequence *sequence = [RACSequence sequence];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		[sequence addObjectAndNilsAreOK:block()];
	});
	
	return sequence;
}

@end
