//
//  NSObject+RACObserverPropertySubject.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@class RACObserverPropertySubject;

@interface NSObject (RACObserverPropertySubject)

// Returns a property subject interface to the receiver's key path.
- (RACObserverPropertySubject *)rac_propertyForKeyPath:(NSString *)keyPath;

@end
