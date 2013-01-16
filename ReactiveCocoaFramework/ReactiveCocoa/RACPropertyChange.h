//
//  RACPropertyChange.h
//  ReactiveCocoa
//
//  Created by Jonathan Toland on 1/14/13.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

@interface RACPropertyChangeBase : NSProxy

@property (nonatomic, assign, readonly) NSKeyValueChange kind;
@property (nonatomic, assign, readonly, getter=isPrior) BOOL prior;
@property (nonatomic, strong, readonly) NSDictionary *KVODictionary;

- (id)initWithChangeDictionary:(NSDictionary *)change;

@end

@interface RACPropertyChange : RACPropertyChangeBase

@property (nonatomic, strong, readonly) id object;
@property (nonatomic, strong, readonly) id oldObject;
@property (nonatomic, assign, readonly) NSUInteger index;

- (id)initWithChangeDictionary:(NSDictionary *)change atIndex:(NSUInteger)index;
- (id)initWithKind:(NSKeyValueChange)kind object:(id)object oldObject:(id)oldObject index:(NSUInteger)index isPrior:(BOOL)isPrior;

@end

@interface RACPropertyChanges : RACPropertyChangeBase // but I haven't seen multiple indexes yet?

@property (nonatomic, copy, readonly) NSArray *objects;
@property (nonatomic, copy, readonly) NSArray *oldObjects;
@property (nonatomic, copy, readonly) NSIndexSet *indexSet;

- (RACSequence *)rac_sequence;
- (id)initWithKind:(NSKeyValueChange)kind objects:(NSArray *)objects oldObjects:(NSArray *)oldObjects indexSet:(NSIndexSet *)indexSet isPrior:(BOOL)isPrior;

@end
