//
//  NSArray+EXTNilSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSArray (EXTNilSupport)

- (id)rac_objectOrNilAtIndex:(NSUInteger)index;

@end
