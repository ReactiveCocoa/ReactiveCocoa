//
//  NSMapTable+RACSupport.h
//  ReactiveCocoa
//
//  Created by Syo Ikeda on 2013-12-24.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSignal;

@interface NSMapTable (RACSupport)

/// A signal that will send RACTuples of the key-value pairs in the map table.
///
/// Mutating the map table will not affect the signal after it's been created.
@property (nonatomic, strong, readonly) RACSignal *rac_signal;

/// A signal that will send all of the keys in the map table.
///
/// Mutating the map table will not affect the signal after it's been created.
@property (nonatomic, strong, readonly) RACSignal *rac_keySignal;

/// A signal that will send all of the values in the map table.
///
/// Mutating the map table will not affect the signal after it's been created.
@property (nonatomic, strong, readonly) RACSignal *rac_valueSignal;

@end
