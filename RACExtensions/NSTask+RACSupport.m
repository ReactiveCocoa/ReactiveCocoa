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

NSString * const NSTaskRACSupportErrorDomain = @"NSTaskRACSupportErrorDomain";

NSString * const NSTaskRACSupportOutputData = @"NSTaskRACSupportOutputData";
NSString * const NSTaskRACSupportErrorData = @"NSTaskRACSupportErrorData";
NSString * const NSTaskRACSupportTask = @"NSTaskRACSupportTask";
NSString * const NSTaskRACSupportOutputString = @"NSTaskRACSupportOutputString";
NSString * const NSTaskRACSupportErrorString = @"NSTaskRACSupportErrorString";
NSString * const NSTaskRACSupportTaskArguments = @"NSTaskRACSupportTaskArguments";

const NSInteger NSTaskRACSupportNonZeroTerminationStatus = 123456;

@implementation NSTask (RACSupport)

- (RACSignal *)rac_standardOutput {
	if(![[self standardOutput] isKindOfClass:[NSPipe class]]) {
		[self setStandardOutput:[NSPipe pipe]];
	}
	
	return [self rac_signalForPipe:[self standardOutput]];
}

- (RACSignal *)rac_standardError {
	if(![[self standardError] isKindOfClass:[NSPipe class]]) {
		[self setStandardError:[NSPipe pipe]];
	}
	
	return [self rac_signalForPipe:[self standardError]];
}

- (RACSignal *)rac_signalForPipe:(NSPipe *)pipe {
	NSFileHandle *fileHandle = [pipe fileHandleForReading];	
	return [fileHandle rac_readInBackground];
}

- (RACSignal *)rac_completion {
	return [[[NSNotificationCenter.defaultCenter rac_addObserverForName:NSTaskDidTerminateNotification object:self] any] mapReplace:RACUnit.defaultUnit];
}

- (RACCancelableSignal *)rac_run {
	return [self rac_runWithScheduler:[RACScheduler immediateScheduler]];
}

- (RACCancelableSignal *)rac_runWithScheduler:(RACScheduler *)scheduler {
	NSParameterAssert(scheduler != nil);
	
	RACReplaySubject *subject = [RACReplaySubject subject];
	
	__block BOOL canceled = NO;
	[RACScheduler.mainThreadScheduler schedule:^{
		NSMutableData * (^aggregateData)(NSMutableData *, NSData *) = ^(NSMutableData *running, NSData *next) {
			[running appendData:next];
			return running;
		};
		
		// TODO: should we aggregate the data on the given scheduler too?
		RACConnectableSignal *outputSignal = [[self.rac_standardOutput aggregateWithStart:[NSMutableData data] combine:aggregateData] publish];
		__block NSData *outputData = nil;
		[outputSignal subscribeNext:^(NSData *accumulatedData) {
			outputData = accumulatedData;
		}];
		
		RACConnectableSignal *errorSignal = [[self.rac_standardError aggregateWithStart:[NSMutableData data] combine:aggregateData] publish];
		__block NSData *errorData = nil;
		[errorSignal subscribeNext:^(NSData *accumulatedData) {
			errorData = accumulatedData;
		}];
				
		// wait until termination's signaled and output and error are done
		[[RACSignal merge:@[ outputSignal, errorSignal, self.rac_completion ]] subscribeNext:^(id _) {
			// nothing
		} completed:^{
			if(canceled) return;
						
			[scheduler schedule:^{
				if(canceled) return;
								
				if([self terminationStatus] == 0) {
					[subject sendNext:outputData];
					[subject sendCompleted];
				} else {
					NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
					if(outputData != nil) {
						[userInfo setObject:outputData forKey:NSTaskRACSupportOutputData];
						
						NSString *string = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
						if(string != nil) [userInfo setObject:string forKey:NSTaskRACSupportOutputString];
					}
					if(errorData != nil) {
						[userInfo setObject:errorData forKey:NSTaskRACSupportErrorData];
						
						NSString *string = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
						if(string != nil) [userInfo setObject:string forKey:NSTaskRACSupportErrorString];
					}
					if([self arguments] != nil) [userInfo setObject:[self arguments] forKey:NSTaskRACSupportTaskArguments];
					[userInfo setObject:self forKey:NSTaskRACSupportTask];
					[subject sendError:[NSError errorWithDomain:NSTaskRACSupportErrorDomain code:NSTaskRACSupportNonZeroTerminationStatus userInfo:userInfo]];
				}
			}];
		}];
		
		[outputSignal connect];
		[errorSignal connect];
		
		[self launch];
	}];
	
	__weak NSTask *weakSelf = self;
	return [subject asCancelableWithBlock:^{
		NSTask *strongSelf = weakSelf;
		canceled = YES;
		[strongSelf terminate];
	}];
}

@end
