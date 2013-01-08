//
//  NSEnumerator+RACSignalAdditions.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 08/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSEnumerator+RACSignalAdditions.h"
#import "RACScheduler.h"

@implementation NSEnumerator (RACSignalAdditions)

- (RACSignal *)rac_signal {
	return [self rac_signalWithScheduler:[RACScheduler scheduler]];
}

- (RACSignal *)rac_signalWithScheduler:(RACScheduler *)scheduler {
	return nil;
}

@end
