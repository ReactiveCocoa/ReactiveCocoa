//
//  RACStringSequence.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "RACStringSequence.h"

@interface RACStringSequence ()

// The string being sequenced.
@property (nonatomic, copy, readonly) NSString *string;

// The index in the string from which the sequence starts.
@property (nonatomic, assign, readonly) NSUInteger offset;

@end

@implementation RACStringSequence

#pragma mark Lifecycle

+ (RACSequence *)sequenceWithString:(NSString *)string offset:(NSUInteger)offset {
	NSCParameterAssert(offset <= string.length);

	if (offset == string.length) return self.empty;

	RACStringSequence *seq = [[self alloc] init];
	seq->_string = [string copy];
	seq->_offset = offset;
	return seq;
}

#pragma mark RACSequence

- (id)head {
	return [self.string substringWithRange:NSMakeRange(self.offset, 1)];
}

- (RACSequence *)tail {
	RACSequence *sequence = [self.class sequenceWithString:self.string offset:self.offset + 1];
	sequence.name = self.name;
	return sequence;
}

- (NSArray *)array {
	NSUInteger substringLength = self.string.length - self.offset;
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:substringLength];

	[self.string enumerateSubstringsInRange:NSMakeRange(self.offset, substringLength) options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
		[array addObject:substring];
	}];

	return [array copy];
}

#pragma mark NSObject

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p>{ name = %@, string = %@ }", self.class, self, self.name, [self.string substringFromIndex:self.offset]];
}

@end
