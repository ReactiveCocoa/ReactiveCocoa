//
//  NSObject+RACCocoaTouchBindings.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 03/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACCocoaTouchBindings.h"
#import "NSObject+RACBindings.h"

@implementation NSObject (RACCocoaTouchBindings)

- (RACDisposable *)rac_bind:(NSString *)receiverKeyPath toObject:(id)otherObject withKeyPath:(NSString *)otherKeyPath {
	return [self rac_bind:receiverKeyPath signalBlock:RACSignalTransformationIdentity toObject:otherObject withKeyPath:otherKeyPath signalBlock:RACSignalTransformationIdentity];
}

@end
