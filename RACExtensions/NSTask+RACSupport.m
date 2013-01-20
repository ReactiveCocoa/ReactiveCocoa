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
#import <ReactiveCocoa/EXTScope.h>

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
	
	return [[self rac_signalForPipe:[self standardOutput]] setNameWithFormat:@"%@ -rac_standardOutput", self];
}

- (RACSignal *)rac_standardError {
	if(![[self standardError] isKindOfClass:[NSPipe class]]) {
		[self setStandardError:[NSPipe pipe]];
	}
	
	return [[self rac_signalForPipe:[self standardError]] setNameWithFormat:@"%@ -rac_standardError", self];
}

- (RACSignal *)rac_signalForPipe:(NSPipe *)pipe {
	NSFileHandle *fileHandle = [pipe fileHandleForReading];	
	return [fileHandle rac_readInBackground];
}

- (RACSignal *)rac_completion {
	return [[[[NSNotificationCenter.defaultCenter rac_addObserverForName:NSTaskDidTerminateNotification object:self]
		any]
		mapReplace:RACUnit.defaultUnit]
		setNameWithFormat:@"%@ -rac_completion", self];
}

- (RACSignal *)rac_run {
	return [self rac_runWithScheduler:[RACScheduler immediateScheduler]];
}

- (RACSignal *)rac_runWithScheduler:(RACScheduler *)scheduler {
	NSParameterAssert(scheduler != nil);
	
	@weakify(self);
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block uint32_t volatile canceled = 0;
		RACDisposable *disposable = [[self rac_launchWithScheduler:scheduler cancelationToken:&canceled] subscribe:subscriber];
		return [RACDisposable disposableWithBlock:^{
			@strongify(self);
			OSAtomicOr32Barrier(1, &canceled);
			[self terminate];
			[disposable dispose];
		}];
	}] replayLazily];
}

- (RACSignal *)rac_launchWithScheduler:(RACScheduler *)scheduler cancelationToken:(volatile uint32_t *)cancelationToken {
	RACReplaySubject *subject = [RACReplaySubject subject];
	[subject setNameWithFormat:@"%@ -rac_runWithScheduler: %@", self, scheduler];

	[RACScheduler.mainThreadScheduler schedule:^{
		NSMutableData * (^aggregateData)(NSMutableData *, NSData *) = ^(NSMutableData *running, NSData *next) {
			[running appendData:next];
			return running;
		};

		// TODO: should we aggregate the data on the given scheduler too?
		RACMulticastConnection *outputConnection = [[self.rac_standardOutput aggregateWithStart:[NSMutableData data] combine:aggregateData] publish];
		__block NSData *outputData = nil;
		[outputConnection.signal subscribeNext:^(NSData *accumulatedData) {
			outputData = accumulatedData;
		}];

		RACMulticastConnection *errorConnection = [[self.rac_standardError aggregateWithStart:[NSMutableData data] combine:aggregateData] publish];
		__block NSData *errorData = nil;
		[errorConnection.signal subscribeNext:^(NSData *accumulatedData) {
			errorData = accumulatedData;
		}];

		// wait until termination's signaled and output and error are done
		[[RACSignal merge:@[ outputConnection.signal, errorConnection.signal, self.rac_completion ]] subscribeNext:^(id _) {
			// nothing
		} completed:^{
			if (*cancelationToken == 1) return;

			[scheduler schedule:^{
				if (*cancelationToken == 1) return;

				if (self.terminationStatus == 0) {
					[subject sendNext:outputData];
					[subject sendCompleted];
				} else {
					NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
					if (outputData != nil) {
						userInfo[NSTaskRACSupportOutputData] = outputData;

						NSString *string = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
						if(string != nil) userInfo[NSTaskRACSupportOutputString] = string;
					}
					
					if (errorData != nil) {
						userInfo[NSTaskRACSupportErrorData] = errorData;

						NSString *string = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
						if(string != nil) userInfo[NSTaskRACSupportErrorString] = string;
					}
					
					if (self.arguments != nil) userInfo[NSTaskRACSupportTaskArguments] = self.arguments;

					userInfo[NSTaskRACSupportTask] = self;
					[subject sendError:[NSError errorWithDomain:NSTaskRACSupportErrorDomain code:NSTaskRACSupportNonZeroTerminationStatus userInfo:userInfo]];
				}
			}];
		}];

		[outputConnection connect];
		[errorConnection connect];

		[self launch];
	}];

	return subject;
}

@end
