//
//  RACCommand.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RACObservableValue.h"


@interface RACCommand : RACObservableValue

@property (nonatomic, strong) RACObservableValue *canExecute;
@property (nonatomic, readonly) BOOL canCurrentlyExecute;

+ (RACCommand *)command;

- (void)execute:(id)sender;

@end
