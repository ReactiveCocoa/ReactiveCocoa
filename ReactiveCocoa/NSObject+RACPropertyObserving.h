//
//  NSObject+RACPropertyObserving.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol RACObservable;


@interface NSObject (RACPropertyObserving)

- (id<RACObservable>)observableForKeyPath:(NSString *)keyPath;
- (id<RACObservable>)observableForBinding:(NSString *)binding;

@end
