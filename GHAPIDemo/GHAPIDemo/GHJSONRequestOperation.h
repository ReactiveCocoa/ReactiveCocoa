//
//  GHJSONRequestOperation.h
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <ReactiveCocoa/ReactiveCocoa.h>
#import "AFJSONRequestOperation.h"


@interface GHJSONRequestOperation : AFJSONRequestOperation <RACAsyncCommandOperation>

@property (nonatomic, strong) void (^RACAsyncCallback)(id returnedValue, BOOL success, NSError *error);

@end
