//
//  RACDelegateProxy.h
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/19/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

// A delegate object suitable for using -rac_signalForSelector:fromProtocol:
// upon.
@interface RACDelegateProxy : NSObject

// The delegate to which messages should be forwarded if not handled by
// any -rac_signalForSelector:fromProtocol: applications.
@property (nonatomic, weak) id rac_proxiedDelegate;

// Creates a delegate proxy which will respond to selectors from `protocol`.
- (instancetype)initWithProtocol:(Protocol *)protocol;

@end
