//
//  RACPropertyChange.h
//  ReactiveCocoa
//
//  Created by Jonathan Toland on 1/14/13.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

@interface RACPropertyChangeBase : NSObject

@property (nonatomic, assign, readonly) NSKeyValueChange kind;
@property (nonatomic, assign, readonly, getter=isPrior) BOOL prior;

- (id)initWithChangeDictionary:(NSDictionary *)change;
+ (instancetype)propertyChangeForDictionary:(NSDictionary *)change;

@end

@interface RACPropertyChange : RACPropertyChangeBase

@property (nonatomic, strong, readonly) id object;
@property (nonatomic, strong, readonly) id oldObject;
@property (nonatomic, assign, readonly) NSUInteger index;

- (id)initWithKind:(NSKeyValueChange)kind object:(id)object oldObject:(id)oldObject index:(NSUInteger)index isPrior:(BOOL)isPrior;

@end

@interface RACPropertyChanges : RACPropertyChangeBase // but I haven't seen multiple indexes yet?

@property (nonatomic, copy, readonly) NSArray *objects;
@property (nonatomic, copy, readonly) NSArray *oldObjects;
@property (nonatomic, copy, readonly) NSIndexSet *indexSet;

- (id)initWithKind:(NSKeyValueChange)kind objects:(NSArray *)objects oldObjects:(NSArray *)oldObjects indexSet:(NSIndexSet *)indexSet isPrior:(BOOL)isPrior;
// XXX: - (RACSequence *)rac_sequence;?
- (void)enumerateChangesUsingBlock:(void (^)(RACPropertyChange *change, BOOL *stop))block;

@end
