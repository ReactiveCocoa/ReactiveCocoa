//
//  RACDelegateProxy.h
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/19/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACEventTrampoline;

@interface RACDelegateProxy : NSObject {
    Protocol *protocol;
    NSObject *delegator;
    id actualDelegate;
    NSMutableSet *trampolines;
}

+ (instancetype)proxyWithProtocol:(Protocol *)protocol andDelegator:(NSObject *)delegator;
- (void)addTrampoline:(RACEventTrampoline *)trampoline;

@property (nonatomic, strong) Protocol *protocol;
@property (nonatomic, strong) NSObject *delegator;
@property (nonatomic, strong) id actualDelegate;

@end
