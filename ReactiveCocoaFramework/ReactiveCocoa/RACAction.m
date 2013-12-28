//
//  RACAction.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-11.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACAction.h"

#import "NSObject+RACDescription.h"
#import "RACCompoundDisposable.h"
#import "RACReplaySubject.h"
#import "RACScheduler.h"
#import "RACSignalGenerator.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"
#import "RACTuple.h"

NSString * const RACActionErrorDomain = @"RACActionErrorDomain";
const NSInteger RACActionErrorNotEnabled = 1;
NSString * const RACActionErrorKey = @"RACActionErrorKey";

@interface RACAction () {
	RACSubject *_results;
	RACSubject *_errors;
	RACSubject *_executionSignals;

	// Although RACReplaySubject is deprecated for consumers, we're going to use it
	// internally for the foreseeable future. We just want to expose something
	// higher level.
	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wdeprecated"
	RACReplaySubject *_enabled;
	RACReplaySubject *_executing;
	#pragma clang diagnostic pop
}

// The generator that the receiver was initialized with.
@property (nonatomic, strong, readonly) RACSignalGenerator *generator;

@end

@implementation RACAction

#pragma mark Lifecycle

- (instancetype)initWithEnabled:(RACSignal *)enabledSignal generator:(RACSignalGenerator *)generator {
	NSCParameterAssert(enabledSignal != nil);
	NSCParameterAssert(generator != nil);

	self = [super init];
	if (self == nil) return nil;

	_generator = generator;

	_results = [[RACSubject subject] setNameWithFormat:@"%@ -results", self];
	_errors = [[RACSubject subject] setNameWithFormat:@"%@ -errors", self];
	_executionSignals = [[RACSubject subject] setNameWithFormat:@"%@ -executionSignals", self];

	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wdeprecated"
	_executing = [[RACReplaySubject replaySubjectWithCapacity:1] setNameWithFormat:@"%@ -executing", self];
	_enabled = [[RACReplaySubject replaySubjectWithCapacity:1] setNameWithFormat:@"%@ -enabled", self];
	#pragma clang diagnostic pop

	[_executing sendNext:@NO];
	[[[RACSignal
		combineLatest:@[
			[enabledSignal startWith:@YES],
			[self.executing not],
		]]
		and]
		subscribe:_enabled];

	return self;
}

- (void)dealloc {
	RACTuple *subjects = RACTuplePack(_results, _errors, _executionSignals, _enabled, _executing);

	[RACScheduler.mainThreadScheduler schedule:^{
		for (id subject in subjects) {
			if (subject == RACTupleNil.tupleNil) continue;

			[subject sendCompleted];
		}
	}];
}

#pragma mark Execution

- (void)execute:(id)input {
	[[self deferred:input] subscribe:nil];
}

- (RACSignal *)deferred:(id)input {
	return [[[RACSignal
		create:^(id<RACSubscriber> subscriber) {
			NSNumber *enabled = [self.enabled first];
			if (!enabled.boolValue) {
				NSError *disabledError = [NSError errorWithDomain:RACActionErrorDomain code:RACActionErrorNotEnabled userInfo:@{
					NSLocalizedDescriptionKey: NSLocalizedString(@"The action is disabled and cannot be executed", nil),
					RACActionErrorKey: self
				}];

				[subscriber sendError:disabledError];
				return;
			}

			#pragma clang diagnostic push
			#pragma clang diagnostic ignored "-Wdeprecated"
			RACReplaySubject *replayed = [[RACReplaySubject subject] setNameWithFormat:@"%@ -deferred: %@", self, [input rac_description]];
			#pragma clang diagnostic pop
			
			[replayed subscribe:subscriber];
			[_executionSignals sendNext:replayed];
			[_executing sendNext:@YES];

			[[[[self.generator
				signalWithValue:input]
				// Errors are handled up here, instead of in the subscription
				// call below, because any error must be forwarded before the
				// `completed` corresponding to disposal.
				doError:^(NSError *error) {
					[replayed sendError:error];

					[RACScheduler.mainThreadScheduler schedule:^{
						[_errors sendNext:error];
					}];
				}]
				doDisposed:^{
					// This handles the case of disposal and `completed`. If an
					// error occurred, it would've already been sent above.
					[replayed sendCompleted];

					[RACScheduler.mainThreadScheduler schedule:^{
						[_executing sendNext:@NO];
					}];
				}]
				subscribeSavingDisposable:^(RACDisposable *disposable) {
					// Allow disposal as early as possible.
					[subscriber.disposable addDisposable:disposable];
				} next:^(id value) {
					[replayed sendNext:value];

					[RACScheduler.mainThreadScheduler schedule:^{
						[_results sendNext:value];
					}];
				} error:nil completed:nil];
		}]
		subscribeOn:RACScheduler.mainThreadScheduler]
		setNameWithFormat:@"%@ -deferred: %@", self, [input rac_description]];
}

@end

@implementation RACSignalGenerator (RACActionAdditions)

- (RACAction *)action {
	return [self actionEnabledIf:[RACSignal empty]];
}

- (RACAction *)actionEnabledIf:(RACSignal *)enabledSignal {
	return [[RACAction alloc] initWithEnabled:enabledSignal generator:self];
}

@end

@implementation RACSignal (RACActionAdditions)

- (RACAction *)action {
	return [self actionEnabledIf:[RACSignal empty]];
}

- (RACAction *)actionEnabledIf:(RACSignal *)enabledSignal {
	RACSignalGenerator *generator = [self signalGenerator];
	return [[RACAction alloc] initWithEnabled:enabledSignal generator:generator];
}

@end
