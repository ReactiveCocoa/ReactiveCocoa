//
//  NSHashTable+RACSupport.h
//  ReactiveCocoa
//
//  Created by Syo Ikeda on 2013-12-21.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSignal;

@interface NSHashTable (RACSupport)

/// A signal that will send all of the objects in the collection.
///
/// Mutating the collection will not affect the signal after it's been created.
///
/// The signal itself does not retain the objects in the collection.
@property (nonatomic, strong, readonly) RACSignal *rac_signal;

@end
