//
//  RACDelegateProxy.h
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/19/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACEventTrampoline;

@interface RACDelegateProxy : NSObject

@property (nonatomic, weak) id actualDelegate;

+ (instancetype)proxyWithProtocol:(Protocol *)protocol andDelegator:(NSObject *)delegator;

- (void)addTrampoline:(RACEventTrampoline *)trampoline;

@end
