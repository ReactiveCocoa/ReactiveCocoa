//
//  NSObject+RACDescription.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-05-13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACDescription.h"
#import "RACTuple.h"

@implementation NSObject (RACDescription)

- (NSString *)rac_description {
#ifdef DEBUG
	return [[NSString alloc] initWithFormat:@"<%@: %p>", self.class, self];
#else
	return @"(description skipped)";
#endif
}

@end

@implementation NSValue (RACDescription)

- (NSString *)rac_description {
	return self.description;
}

@end

@implementation NSString (RACDescription)

- (NSString *)rac_description {
	return self.description;
}

@end

@implementation RACTuple (RACDescription)

- (NSString *)rac_description {
	return self.allObjects.description;
}

@end
