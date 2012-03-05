//
//  RACValue.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACSequence.h"

#define rac_synthesize_val(a, val) \
	@synthesize a; \
	- (RACValue *)a { \
		if(a == nil) { \
			a = [RACValue valueWithValue:val]; \
		} \
		return a; \
	}


@interface RACValue : RACSequence

@property (nonatomic, strong) id value; // KVO-compliant

+ (id)valueWithValue:(id)v;
+ (id)value;

@end
