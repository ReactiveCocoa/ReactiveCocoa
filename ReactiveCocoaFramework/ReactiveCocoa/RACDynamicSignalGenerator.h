//
//  RACDynamicSignalGenerator.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-06.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignalGenerator.h"

/// A generator that implements its behavior using a block.
@interface RACDynamicSignalGenerator : RACSignalGenerator

/// Creates a signal generator using the given block.
///
/// block - Describes how to create a signal from an input value, which may be
///         nil. This block must not be nil, and must not return a nil signal.
+ (instancetype)generatorWithBlock:(RACSignal * (^)(id input))block;

/// Behaves like -generatorWithBlock:, but allows the block to invoke other
/// methods upon the generator.
///
/// block - Describes how to create a signal from an input value, which may be
///         nil. The `generator` argument will be the instantiated generator,
///         and can be used to generate additional signals if desired. This
///         block must not be nil, and must not return a nil signal.
///
/// Examples
///
///   // Fetches users from the API, starting at the given page.
///   RACSignalGenerator *fetchUsers = [RACDynamicSignalGenerator generatorWithReflexiveBlock:^(NSNumber *pageNum, RACSignalGenerator *generator) {
///       return [[APIClient.sharedClient
///           fetchUsersAtPage:pageNum.intValue]
///           flattenMap:^(Page *page) {
///               RACSignal *moreUsers = [RACSignal empty];
///
///               // Fetch the next page, if there is one.
///               if (![page isLastPage]) {
///                   moreUsers = [generator signalWithValue:@(pageNum.intValue + 1)];
///               }
///
///               // Concatenate all results.
///               return [[RACSignal
///                   return:page]
///                   concat:moreUsers];
///           }];
///   }];
+ (instancetype)generatorWithReflexiveBlock:(RACSignal * (^)(id input, RACDynamicSignalGenerator *generator))block;

@end
