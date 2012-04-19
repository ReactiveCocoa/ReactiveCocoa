//
//  GHDLoginViewController.h
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/5/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

@class GHDLoginView;


@interface GHDLoginViewController : NSViewController

@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, assign, readonly) BOOL successHidden;
@property (nonatomic, assign, readonly) BOOL loginFailedHidden;
@property (nonatomic, assign, readonly) BOOL loginEnabled;
@property (nonatomic, assign, readonly) BOOL loggingIn;
@property (nonatomic, strong, readonly) RACAsyncCommand *loginCommand;
@property (nonatomic, strong, readonly) RACSubject *didLoginSubject;

@end
