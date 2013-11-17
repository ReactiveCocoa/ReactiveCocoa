//
//  RACTransactionSignalGenerator.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-12.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACTransactionSignalGenerator.h"
#import "RACSubject.h"

@interface RACTransactionSignalGenerator () {
	RACSubject *_transactions;
}

// The generator that the receiver is decorating.
@property (nonatomic, strong, readonly) RACSignalGenerator *baseGenerator;

@end

@implementation RACTransactionSignalGenerator

#pragma mark Lifecycle

- (id)initWithGenerator:(RACSignalGenerator *)generator {
	NSCParameterAssert(generator != nil);

	self = [super init];
	if (self == nil) return nil;

	_baseGenerator = generator;
	_transactions = [[RACSubject subject] setNameWithFormat:@"transactions"];

	return self;
}

- (void)dealloc {
	[_transactions sendCompleted];
}

#pragma mark Generation

- (RACSignal *)signalWithValue:(id)input {
	RACSignal *signal = [self.baseGenerator signalWithValue:input];

	[_transactions sendNext:signal];
	return signal;
}

@end

@implementation RACSignalGenerator (RACTransactionSignalGeneratorAdditions)

- (RACTransactionSignalGenerator *)asTransactionSignalGenerator {
	return [[RACTransactionSignalGenerator alloc] initWithGenerator:self];
}

@end
