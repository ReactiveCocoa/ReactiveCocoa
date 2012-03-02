//
//  RACObservableArray_Private.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACObservableSequence.h"


@interface RACObservableSequence ()

@property (nonatomic, readonly) NSUInteger count;

- (id)initWithCapacity:(NSUInteger)cap;

- (void)addObjectAndNilsAreOK:(id)object;
- (void)removeFirstObject;
- (id)lastObject;

@end
