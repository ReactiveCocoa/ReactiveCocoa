//
//  RACPropertyChange.m
//  ReactiveCocoa
//
//  Created by Jonathan Toland on 1/14/13.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <ReactiveCocoa/EXTKeyPathCoding.h>
#import "RACPropertyChange.h"

@interface RACPropertyChangeBase (Protected)

- (id)initWithKind:(NSKeyValueChange)kind isPrior:(BOOL)isPrior;
- (NSMutableDictionary *)descriptor;

@end

@implementation RACPropertyChangeBase

- (id)initWithChangeDictionary:(NSDictionary *)change {
	return [self initWithKind:(NSKeyValueChange) ((NSNumber *) change[NSKeyValueChangeKindKey]).unsignedIntegerValue
			isPrior:((NSNumber *) change[NSKeyValueChangeNotificationIsPriorKey]).boolValue];
}

+ (instancetype)propertyChangeForDictionary:(NSDictionary *)change {
	if (self == [RACPropertyChangeBase class]) {
		BOOL hasMany = ((NSIndexSet *) change[NSKeyValueChangeIndexesKey]).count > 1;
		Class impl = hasMany ? [RACPropertyChanges class] : [RACPropertyChange class];
		return [impl propertyChangeForDictionary:change];
	} else {
		return [[self alloc] initWithChangeDictionary:change];
	}
}

- (id)initWithKind:(NSKeyValueChange)kind isPrior:(BOOL)isPrior {
	if (self = [self init]) {
		_kind = kind;
		_prior = isPrior;
	}
	return self;
}

- (NSMutableDictionary *)descriptor {
	static NSArray *kindDescriptions;
	static dispatch_once_t once[1];
	dispatch_once(once, ^{
		kindDescriptions = @[
				@metamacro_stringify(NSKeyValueChangeSetting),
				@metamacro_stringify(NSKeyValueChangeInsertion),
				@metamacro_stringify(NSKeyValueChangeRemoval),
				@metamacro_stringify(NSKeyValueChangeReplacement),
		];
	});
	return @{
			@keypath(self.kind) : kindDescriptions[self.kind - 1],
			@keypath(self.prior) : self.prior ? @"YES" : @"NO",
	}.mutableCopy;
}

- (NSString *)description {
	return self.descriptor.description;
}

@end

@implementation RACPropertyChange

- (id)initWithKind:(NSKeyValueChange)kind object:(id)object oldObject:(id)oldObject index:(NSUInteger)index isPrior:(BOOL)isPrior {
	if (self = [self initWithKind:kind isPrior:isPrior]) {
		[self commonInitWithObject:object oldObject:oldObject index:index];
	}
	return self;
}

- (id)initWithChangeDictionary:(NSDictionary *)change {
	NSIndexSet *indexSet = change[NSKeyValueChangeIndexesKey];
	if (self = [super initWithChangeDictionary:change]) {
		id object = change[NSKeyValueChangeNewKey];
		id oldObject = change[NSKeyValueChangeOldKey];
		if (indexSet.count == 1) {
			[self commonInitWithObject:((NSArray *) object).lastObject oldObject:((NSArray *) oldObject).lastObject index:indexSet.lastIndex];
		} else {
			[self commonInitWithObject:object oldObject:oldObject index:NSNotFound];
		}
	}
	return self;
}

- (NSMutableDictionary *)descriptor {
	NSMutableDictionary *descriptor = super.descriptor;
	[descriptor addEntriesFromDictionary:@{
			@keypath(self.object) : self.object ? : @"nil",
			@keypath(self.oldObject) : self.oldObject ? : @"nil",
			@keypath(self.index) : self.index == NSNotFound ? @metamacro_stringify(NSNotFound) : [NSNumber numberWithUnsignedInteger:self.index],
	}];
	return descriptor;
}

- (void)commonInitWithObject:(id)object oldObject:(id)oldObject index:(NSUInteger)index {
	_object = object;
	_oldObject = oldObject;
	_index = index;
}

@end

@implementation RACPropertyChanges

- (id)initWithKind:(NSKeyValueChange)kind objects:(NSArray *)objects oldObjects:(NSArray *)oldObjects indexSet:(NSIndexSet *)indexSet isPrior:(BOOL)isPrior {
	if (self = [self initWithKind:kind isPrior:isPrior]) {
		[self commonInitWithObjects:objects oldObjects:oldObjects indexSet:indexSet];
	}
	return self;
}

- (void)enumerateChangesUsingBlock:(void (^)(RACPropertyChange *, BOOL *))block {
	NSEnumerator *eachObject = self.objects.objectEnumerator;
	NSEnumerator *eachOldObject = self.oldObjects.objectEnumerator;
	[self.indexSet enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
		block([[RACPropertyChange alloc]
				initWithKind:self.kind
				object:eachObject.nextObject
				oldObject:eachOldObject.nextObject
				index:index
				isPrior:self.prior], stop);
	}];
}

- (id)initWithChangeDictionary:(NSDictionary *)change {
	if (self = [super initWithChangeDictionary:change]) {
		[self commonInitWithObjects:change[NSKeyValueChangeNewKey]
				oldObjects:change[NSKeyValueChangeOldKey]
				indexSet:change[NSKeyValueChangeIndexesKey]];
	}
	return self;
}

- (NSMutableDictionary *)descriptor {
	NSMutableDictionary *descriptor = super.descriptor;
	[descriptor addEntriesFromDictionary:@{
			@keypath(self.objects) : self.objects ? : @"nil",
			@keypath(self.oldObjects) : self.oldObjects ? : @"nil",
			@keypath(self.indexSet) : self.indexSet ? : @"nil",
	}];
	return descriptor;
}

- (void)commonInitWithObjects:(NSArray *)objects oldObjects:(NSArray *)oldObjects indexSet:(NSIndexSet *)indexSet {
	_objects = objects;
	_oldObjects = oldObjects;
	_indexSet = indexSet;
}

@end
