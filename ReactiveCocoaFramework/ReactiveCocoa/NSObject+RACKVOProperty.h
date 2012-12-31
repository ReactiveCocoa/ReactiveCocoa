//
//  NSObject+RACKVOProperty.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@class RACKVOProperty;

@interface NSObject (RACKVOProperty)

// Returns a property interface to the receiver's key path.
- (RACKVOProperty *)rac_propertyForKeyPath:(NSString *)keyPath;

@end
