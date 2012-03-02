//
//  RACObservableArray.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RACObservable.h"


@interface RACObservableArray : NSMutableArray <RACObservable>

+ (RACObservableArray *)arrayWithArray:(NSArray *)array;

@end
