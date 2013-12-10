//
//  RACAggregatingSignalGenerator.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-10.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACAggregatingSignalGenerator.h"
#import "NSObject+RACDescription.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"

@interface RACAggregatingSignalGenerator () {
	RACSubject *_generatedSignals;
}

@property (nonatomic, strong, readonly) RACSignalGenerator *underlyingGenerator;

@end

@implementation RACAggregatingSignalGenerator

#pragma mark Lifecycle

- (id)initWithGenerator:(RACSignalGenerator *)generator {
	NSCParameterAssert(generator != nil);

	self = [super init];
	if (self == nil) return nil;

	_underlyingGenerator = generator;
	_generatedSignals = [[RACSubject subject] setNameWithFormat:@"%@ -generatedSignals", self];

	return self;
}

- (void)dealloc {
	[_generatedSignals sendCompleted];
}

#pragma mark Generation

- (RACSignal *)signalWithValue:(id)input {
	RACSignal *baseSignal = [self.underlyingGenerator signalWithValue:input];

	return [[RACSignal
		create:^(id<RACSubscriber> subscriber) {
			RACSignal *forwardingSignal = [[[baseSignal
				doNext:^(id x) {
					[subscriber sendNext:x];
				}]
				doError:^(NSError *error) {
					[subscriber sendError:error];
				}]
				doCompleted:^{
					[subscriber sendCompleted];
				}];

			[_generatedSignals sendNext:forwardingSignal];
		}]
		setNameWithFormat:@"%@ -signalWithValue: %@", self, [input rac_description]];
}

@end
