//
//  RACReduce.h
//  ReactiveCocoa
//
//  Created by Dave Lee on 4/7/14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RACTuple.h"
#import "metamacros.h"

#define RACReduce_define_for_type(INDEX, _, TYPE) \
	metamacro_foreach_cxt_recursive(RACReduce_overload,, TYPE, 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15)

#define RACReduce_overload(INDEX, TYPE, ARITY) \
	static inline __attribute__((overloadable)) \
	TYPE (^RACReduce(TYPE (^block)(id metamacro_for_cxt(INDEX, RACReduce_arg_type,,))))(RACTuple *) { \
		return ^(RACTuple *tuple) { \
			return block(tuple[0] metamacro_for_cxt(INDEX, RACReduce_tuple_value,,)); \
		}; \
	}

#define RACReduce_arg_type(INDEX, _) ,id
#define RACReduce_tuple_value(INDEX, _) ,tuple[metamacro_inc(INDEX)]

metamacro_foreach_cxt(RACReduce_define_for_type,,, id, BOOL, void)
