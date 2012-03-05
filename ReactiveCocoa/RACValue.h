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


// A value is a sequence with a single object.
// It only ever sends the `next` event. It does this when `value` changes. It passes that new value in `next`.
@interface RACValue : RACSequence

@property (nonatomic, strong) id value; // KVO-compliant

// Creates a new value with the given object.
//
// v - the value for the object. Can be nil.
+ (id)valueWithValue:(id)v;

// Creates a new value with a nil value.
+ (id)value;

@end
