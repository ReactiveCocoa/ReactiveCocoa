//
//  RACAppDelegate.h
//  ReactiveCocoa-iOS-UIKitTestHost
//
//  Created by Andrew Mackenzie-Ross on 27/06/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RACAppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow *window;

+ (instancetype)delegate;

@end
