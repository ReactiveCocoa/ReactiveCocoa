//
//  UIWebView+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Jackson Harper on 9/23/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACSignal;

@interface UIWebView (RACSignalSupport)

- (RACSignal *)rac_loadedSignal;

@end
