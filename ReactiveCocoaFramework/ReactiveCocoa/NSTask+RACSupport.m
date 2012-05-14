//
//  NSTask+RACSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/10/12.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "NSTask+RACSupport.h"
#import "NSFileHandle+RACSupport.h"
#import "NSNotificationCenter+RACSupport.h"
#import "RACConnectableSubscribable.h"
#import "RACSubscribable+Operations.h"
#import "NSObject+RACSubscribable.h"
#import "RACSubscribable+Operations.h"
#import "RACAsyncSubject.h"
#import "RACScheduler.h"
#import "RACUnit.h"

NSString * const NSTaskRACSupportErrorDomain = @"NSTaskRACSupportErrorDomain";

NSString * const NSTaskRACSupportOutputData = @"NSTaskRACSupportOutputData";
NSString * const NSTaskRACSupportErrorData = @"NSTaskRACSupportErrorData";
NSString * const NSTaskRACSupportTask = @"NSTaskRACSupportTask";

const NSInteger NSTaskRACSupportNonZeroTerminationStatus = 123456;


@implementation NSTask (RACSupport)

- (RACSubscribable *)rac_standardOutputSubscribable {
	if(![[self standardOutput] isKindOfClass:[NSPipe class]]) {
		[self setStandardOutput:[NSPipe pipe]];
	}
	
	return [self rac_subscribableForPipe:[self standardOutput]];
}

- (RACSubscribable *)rac_standardErrorSubscribable {
	if(![[self standardError] isKindOfClass:[NSPipe class]]) {
		[self setStandardError:[NSPipe pipe]];
	}
	
	return [self rac_subscribableForPipe:[self standardError]];
}

- (RACSubscribable *)rac_subscribableForPipe:(NSPipe *)pipe {
	NSFileHandle *fileHandle = [pipe fileHandleForReading];	
	return [fileHandle rac_readInBackground];
}

- (RACSubscribable *)rac_completionSubscribable {
	return [[[[NSNotificationCenter defaultCenter] rac_addObserverForName:NSTaskDidTerminateNotification object:self] any] select:^(id _) {
		return [RACUnit defaultUnit];
	}];
}

- (RACSubscribable *)rac_run {
	return [self rac_runWithScheduler:[RACScheduler immediateScheduler]];
}

- (RACSubscribable *)rac_runWithScheduler:(RACScheduler *)scheduler {
	NSParameterAssert(scheduler != nil);
	
	NSMutableData * (^aggregateData)(NSMutableData *, NSData *) = ^(NSMutableData *running, NSData *next) {
		[running appendData:next];
		return running;
	};
	
	RACConnectableSubscribable *outputSubscribable = [[[self rac_standardOutputSubscribable] aggregateWithStart:[NSMutableData data] combine:aggregateData] publish];
	__block NSData *outputData = nil;
	[outputSubscribable subscribeNext:^(NSData *accumulatedData) {
		outputData = accumulatedData;
	}];
	
	RACConnectableSubscribable *errorSubscribable = [[[self rac_standardErrorSubscribable] aggregateWithStart:[NSMutableData data] combine:aggregateData] publish];
	__block NSData *errorData = nil;
	[errorSubscribable subscribeNext:^(NSData *accumulatedData) {
		errorData = accumulatedData;
	}];
		
	RACAsyncSubject *subject = [RACAsyncSubject subject];
	// wait until termination's signaled and output and error are done
	[[RACSubscribable merge:[NSArray arrayWithObjects:outputSubscribable, errorSubscribable, [self rac_completionSubscribable], nil]] subscribeNext:^(id _) {
		// nothing
	} completed:^{
		if([self terminationStatus] == 0) {
			[subject sendNext:outputData];
			[subject sendCompleted];
		} else {
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
			if(outputData != nil) [userInfo setObject:outputData forKey:NSTaskRACSupportOutputData];
			if(errorData != nil) [userInfo setObject:errorData forKey:NSTaskRACSupportErrorData];
			[userInfo setObject:self forKey:NSTaskRACSupportTask];
			[subject sendError:[NSError errorWithDomain:NSTaskRACSupportErrorDomain code:NSTaskRACSupportNonZeroTerminationStatus userInfo:userInfo]];
		}
	}];
	
	[outputSubscribable connect];
	[errorSubscribable connect];
	
	[scheduler schedule:^{
		[self launch];
		[self waitUntilExit];
	}];
	
	return subject;
}

@end
