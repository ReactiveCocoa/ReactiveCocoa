//
//  RACReduce.h
//  ReactiveCocoa
//
//  Created by Dave Lee on 4/7/14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RACTuple.h"

/// RACReduce() converts a block taking one or more object parameters to a block
/// taking a single RACTuple * parameter. The return type can be any of id,
/// BOOL, or void.
///
/// The purpose of RACReduce() is to allow for literal block parameters when
/// using signals of tuples.
///
/// Examples
///
///   [combinedSignal filter:RACReduce(^ BOOL (NSNumber *currentValue, NSNumber *minimumThreshold) {
///       return currentValue.integerValue >= minimumThreshold.integerValue;
///   })];
///
///   [delegateSignal flattenMap:RACReduce(^(id _, id result, NSError *error) {
///       return (error != nil) ? [RACSignal error:error] : [RACSignal return:result];
///   })];
///
///   [miltivalueSignal subscribeNext:RACReduce(^(NSString *firstName, NSString *lastName) {
///       self.firstName = firstName;
///       self.lastName = lastName;
///   })];

static inline __attribute__((overloadable))
id (^RACReduce(id (^block)(id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 1);
		return block(t[0]);
	};
}

static inline __attribute__((overloadable))
id (^RACReduce(id (^block)(id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 2);
		return block(t[0],t[1]);
	};
}

static inline __attribute__((overloadable))
id (^RACReduce(id (^block)(id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 3);
		return block(t[0],t[1],t[2]);
	};
}

static inline __attribute__((overloadable))
id (^RACReduce(id (^block)(id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 4);
		return block(t[0],t[1],t[2],t[3]);
	};
}

static inline __attribute__((overloadable))
id (^RACReduce(id (^block)(id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 5);
		return block(t[0],t[1],t[2],t[3],t[4]);
	};
}

static inline __attribute__((overloadable))
id (^RACReduce(id (^block)(id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 6);
		return block(t[0],t[1],t[2],t[3],t[4],t[5]);
	};
}

static inline __attribute__((overloadable))
id (^RACReduce(id (^block)(id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 7);
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6]);
	};
}

static inline __attribute__((overloadable))
id (^RACReduce(id (^block)(id,id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 8);
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7]);
	};
}

static inline __attribute__((overloadable))
id (^RACReduce(id (^block)(id,id,id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 9);
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8]);
	};
}

static inline __attribute__((overloadable))
id (^RACReduce(id (^block)(id,id,id,id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 10);
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8],t[9]);
	};
}

static inline __attribute__((overloadable))
BOOL (^RACReduce(BOOL (^block)(id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 1);
		return block(t[0]);
	};
}

static inline __attribute__((overloadable))
BOOL (^RACReduce(BOOL (^block)(id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 2);
		return block(t[0],t[1]);
	};
}

static inline __attribute__((overloadable))
BOOL (^RACReduce(BOOL (^block)(id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 3);
		return block(t[0],t[1],t[2]);
	};
}

static inline __attribute__((overloadable))
BOOL (^RACReduce(BOOL (^block)(id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 4);
		return block(t[0],t[1],t[2],t[3]);
	};
}

static inline __attribute__((overloadable))
BOOL (^RACReduce(BOOL (^block)(id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 5);
		return block(t[0],t[1],t[2],t[3],t[4]);
	};
}

static inline __attribute__((overloadable))
BOOL (^RACReduce(BOOL (^block)(id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 6);
		return block(t[0],t[1],t[2],t[3],t[4],t[5]);
	};
}

static inline __attribute__((overloadable))
BOOL (^RACReduce(BOOL (^block)(id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 7);
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6]);
	};
}

static inline __attribute__((overloadable))
BOOL (^RACReduce(BOOL (^block)(id,id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 8);
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7]);
	};
}

static inline __attribute__((overloadable))
BOOL (^RACReduce(BOOL (^block)(id,id,id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 9);
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8]);
	};
}

static inline __attribute__((overloadable))
BOOL (^RACReduce(BOOL (^block)(id,id,id,id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 10);
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8],t[9]);
	};
}

static inline __attribute__((overloadable))
void (^RACReduce(void (^block)(id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 1);
		return block(t[0]);
	};
}

static inline __attribute__((overloadable))
void (^RACReduce(void (^block)(id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 2);
		return block(t[0],t[1]);
	};
}

static inline __attribute__((overloadable))
void (^RACReduce(void (^block)(id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 3);
		return block(t[0],t[1],t[2]);
	};
}

static inline __attribute__((overloadable))
void (^RACReduce(void (^block)(id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 4);
		return block(t[0],t[1],t[2],t[3]);
	};
}

static inline __attribute__((overloadable))
void (^RACReduce(void (^block)(id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 5);
		return block(t[0],t[1],t[2],t[3],t[4]);
	};
}

static inline __attribute__((overloadable))
void (^RACReduce(void (^block)(id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 6);
		return block(t[0],t[1],t[2],t[3],t[4],t[5]);
	};
}

static inline __attribute__((overloadable))
void (^RACReduce(void (^block)(id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 7);
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6]);
	};
}

static inline __attribute__((overloadable))
void (^RACReduce(void (^block)(id,id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 8);
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7]);
	};
}

static inline __attribute__((overloadable))
void (^RACReduce(void (^block)(id,id,id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 9);
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8]);
	};
}

static inline __attribute__((overloadable))
void (^RACReduce(void (^block)(id,id,id,id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		NSCParameterAssert(t.count == 10);
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8],t[9]);
	};
}
