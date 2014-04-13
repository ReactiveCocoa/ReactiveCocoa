//
//  RACReduce.h
//  ReactiveCocoa
//
//  Created by Dave Lee on 4/7/14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RACTuple.h"

static inline __attribute__((overloadable))
id (^RACReduce(id (^block)(id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0]);
	};
}

static inline __attribute__((overloadable))
id (^RACReduce(id (^block)(id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1]);
	};
}

static inline __attribute__((overloadable))
id (^RACReduce(id (^block)(id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2]);
	};
}

static inline __attribute__((overloadable))
id (^RACReduce(id (^block)(id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2],t[3]);
	};
}

static inline __attribute__((overloadable))
id (^RACReduce(id (^block)(id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2],t[3],t[4]);
	};
}

static inline __attribute__((overloadable))
id (^RACReduce(id (^block)(id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2],t[3],t[4],t[5]);
	};
}

static inline __attribute__((overloadable))
id (^RACReduce(id (^block)(id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6]);
	};
}

static inline __attribute__((overloadable))
id (^RACReduce(id (^block)(id,id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7]);
	};
}

static inline __attribute__((overloadable))
id (^RACReduce(id (^block)(id,id,id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8]);
	};
}

static inline __attribute__((overloadable))
id (^RACReduce(id (^block)(id,id,id,id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8],t[9]);
	};
}

static inline __attribute__((overloadable))
BOOL (^RACReduce(BOOL (^block)(id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0]);
	};
}

static inline __attribute__((overloadable))
BOOL (^RACReduce(BOOL (^block)(id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1]);
	};
}

static inline __attribute__((overloadable))
BOOL (^RACReduce(BOOL (^block)(id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2]);
	};
}

static inline __attribute__((overloadable))
BOOL (^RACReduce(BOOL (^block)(id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2],t[3]);
	};
}

static inline __attribute__((overloadable))
BOOL (^RACReduce(BOOL (^block)(id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2],t[3],t[4]);
	};
}

static inline __attribute__((overloadable))
BOOL (^RACReduce(BOOL (^block)(id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2],t[3],t[4],t[5]);
	};
}

static inline __attribute__((overloadable))
BOOL (^RACReduce(BOOL (^block)(id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6]);
	};
}

static inline __attribute__((overloadable))
BOOL (^RACReduce(BOOL (^block)(id,id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7]);
	};
}

static inline __attribute__((overloadable))
BOOL (^RACReduce(BOOL (^block)(id,id,id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8]);
	};
}

static inline __attribute__((overloadable))
BOOL (^RACReduce(BOOL (^block)(id,id,id,id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8],t[9]);
	};
}

static inline __attribute__((overloadable))
void (^RACReduce(void (^block)(id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0]);
	};
}

static inline __attribute__((overloadable))
void (^RACReduce(void (^block)(id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1]);
	};
}

static inline __attribute__((overloadable))
void (^RACReduce(void (^block)(id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2]);
	};
}

static inline __attribute__((overloadable))
void (^RACReduce(void (^block)(id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2],t[3]);
	};
}

static inline __attribute__((overloadable))
void (^RACReduce(void (^block)(id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2],t[3],t[4]);
	};
}

static inline __attribute__((overloadable))
void (^RACReduce(void (^block)(id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2],t[3],t[4],t[5]);
	};
}

static inline __attribute__((overloadable))
void (^RACReduce(void (^block)(id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6]);
	};
}

static inline __attribute__((overloadable))
void (^RACReduce(void (^block)(id,id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7]);
	};
}

static inline __attribute__((overloadable))
void (^RACReduce(void (^block)(id,id,id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8]);
	};
}

static inline __attribute__((overloadable))
void (^RACReduce(void (^block)(id,id,id,id,id,id,id,id,id,id)))(RACTuple *) {
	return ^(RACTuple *t) {
		return block(t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8],t[9]);
	};
}

