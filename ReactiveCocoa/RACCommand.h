//
//  RACCommand.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RACValue.h"


@interface RACCommand : RACValue

@property (nonatomic, strong) RACValue *canExecuteValue;

+ (RACCommand *)command;
+ (RACCommand *)commandWithCanExecute:(BOOL (^)(id value))canExecuteBlock execute:(void (^)(id value))executeBlock;

- (BOOL)canExecute:(id)value;
- (void)execute:(id)value;

@end
