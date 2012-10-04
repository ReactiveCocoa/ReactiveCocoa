//
//  RACTestObject.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/18/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RACTestObject : NSObject

@property (nonatomic, strong) id objectValue;
@property (nonatomic, assign) NSInteger integerValue;
@property (nonatomic, assign) char *charPointerValue;

- (void)setObjectValue:(id)objectValue andIntegerValue:(NSInteger)integerValue;

@end
