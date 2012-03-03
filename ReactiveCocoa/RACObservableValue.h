//
//  RACObservableValue.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACObservableSequence.h"

#define rac_synthesize_val(a, val) \
	@synthesize a; \
	- (RACObservableValue *)a { \
		if(a == nil) { \
			a = [RACObservableValue valueWithValue:val]; \
		} \
		return a; \
	}


@interface RACObservableValue : RACObservableSequence

@property (nonatomic, strong) id value; // KVO-compliant

+ (id)valueWithValue:(id)v;
+ (id)value;

@end
