//
//  RACStringSequence.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "RACStringSequence.h"
#import "EXTScope.h"

@interface RACStringSequence ()

// The string being sequenced.
@property (nonatomic, copy, readonly) NSString *string;

// The index in the string from which the sequence starts.
@property (nonatomic, assign, readonly) NSUInteger offset;

@end

@implementation RACStringSequence

#pragma mark Lifecycle

+ (RACSequence *)sequenceWithString:(NSString *)string offset:(NSUInteger)offset {
	NSParameterAssert(offset <= string.length);

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
	return [self.class sequenceWithString:self.string offset:self.offset + 1];
}

- (NSArray *)array {
	NSUInteger substringLength = self.string.length - self.offset;
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:substringLength];

	@autoreleasepool {
		unichar *characters = malloc(sizeof(*characters) * substringLength);
		@onExit {
			free(characters);
		};
		
		[self.string getCharacters:characters range:NSMakeRange(self.offset, substringLength)];

		for (NSUInteger i = 0; i < substringLength; i++) {
			NSString *charStr = [NSString stringWithCharacters:characters + i length:1];
			[array addObject:charStr];
		}
	}
	
	return [array copy];
}

#pragma mark NSObject

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p>{ string = %@ }", self.class, self, [self.string substringFromIndex:self.offset]];
}

@end
