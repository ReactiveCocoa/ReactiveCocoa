//
//  RACObservableValue.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACObservableSequence.h"


@interface RACObservableValue : RACObservableSequence

@property (nonatomic, strong) id value; // KVO-compliant

+ (id)valueWithValue:(id)v;

@end
