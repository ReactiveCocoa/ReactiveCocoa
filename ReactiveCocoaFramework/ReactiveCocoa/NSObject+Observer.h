//
//  NSObject+Observer.h
//  ReactiveCocoa
//
//  Created by Brian Semiglia on 3/10/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (Observer)

- (void)addobserver:(id)observer
  withUpdateHandler:(void(^)(id object))updateHandler;

@end
