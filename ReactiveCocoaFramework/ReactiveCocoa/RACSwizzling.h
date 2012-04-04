//
//  RACSwizzling.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


extern void RACSwizzle(Class class, SEL originalSelector, SEL newSelector);
