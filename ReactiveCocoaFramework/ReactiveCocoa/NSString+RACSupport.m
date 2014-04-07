//
//  NSString+RACSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/11/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSString+RACSupport.h"
#import "NSObject+RACDescription.h"
#import "RACCompoundDisposable.h"
#import "RACReduce.h"
#import "RACReplaySubject.h"
#import "RACSignal+Operations.h"
#import "RACStringSequence.h"
#import "RACSubscriber.h"
#import "RACTuple.h"

@implementation NSString (RACSupport)

- (RACSignal *)rac_substringsInRange:(NSRange)range options:(NSStringEnumerationOptions)options {
	NSString *string = [self copy];

	return [[RACSignal
		create:^(id<RACSubscriber> subscriber) {
			[string enumerateSubstringsInRange:range options:options usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
				NSValue *substringValue = [NSValue valueWithRange:substringRange];
				NSValue *enclosingValue = [NSValue valueWithRange:enclosingRange];
				[subscriber sendNext:RACTuplePack(substring, substringValue, enclosingValue)];

				*stop = subscriber.disposable.disposed;
			}];

			[subscriber sendCompleted];
		}]
		setNameWithFormat:@"%@ -rac_substringsInRange: %@ options: %li", self.rac_description, NSStringFromRange(range), (long)options];
}

+ (RACSignal *)rac_contentsAndEncodingOfURL:(NSURL *)URL {
	NSCParameterAssert(URL != nil);

	return [[RACSignal
		create:^(id<RACSubscriber> subscriber) {
			NSStringEncoding encoding;
			NSError *error = nil;
			NSString *string = [NSString stringWithContentsOfURL:URL usedEncoding:&encoding error:&error];
			if (string == nil) {
				[subscriber sendError:error];
			} else {
				[subscriber sendNext:RACTuplePack(string, @(encoding))];
				[subscriber sendCompleted];
			}
		}]
		setNameWithFormat:@"+rac_contentsAndEncodingOfURL: %@", URL];
}

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

@implementation NSString (RACSupportDeprecated)

- (RACSequence *)rac_sequence {
	return [RACStringSequence sequenceWithString:self offset:0];
}

+ (RACSignal *)rac_readContentsOfURL:(NSURL *)URL usedEncoding:(NSStringEncoding *)encoding scheduler:(RACScheduler *)scheduler {
	NSCParameterAssert(scheduler != nil);

	RACReplaySubject *subject = [RACReplaySubject subject];
	[[[[[self
		rac_contentsAndEncodingOfURL:URL]
		subscribeOn:scheduler]
		doNext:RACReduce(^(NSString *contents, NSNumber *boxedEncoding) {
			[subject sendNext:contents];

			// lol this is so ridiculously unsafe
			*encoding = boxedEncoding.unsignedIntegerValue;
		})]
		ignoreValues]
		subscribe:subject];

	return subject;
}

@end

#pragma clang diagnostic pop
