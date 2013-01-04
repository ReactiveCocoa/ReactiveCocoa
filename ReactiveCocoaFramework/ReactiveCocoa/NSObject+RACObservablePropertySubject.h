//
//  NSObject+RACObservablePropertySubject.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@class RACObservablePropertySubject;

@interface NSObject (RACObservablePropertySubject)

// Returns a property subject interface to the receiver's key path.
- (RACObservablePropertySubject *)rac_propertyForKeyPath:(NSString *)keyPath;

@end
