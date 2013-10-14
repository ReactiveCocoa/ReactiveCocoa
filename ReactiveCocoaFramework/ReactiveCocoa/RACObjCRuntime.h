//
//  RACObjCRuntime.h
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/19/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RACObjCRuntime : NSObject

/// Invokes objc_allocateClassPair(). Can be called from ARC code.
+ (Class)createClass:(const char *)className inheritingFromClass:(Class)superclass;

@end
