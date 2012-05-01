//
//  UITextField+RACSubscribableSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACSubscribable;


@interface UITextField (RACSubscribableSupport)

// Creates and returns a subscribable for the text of the field.
- (RACSubscribable *)rac_textSubscribable;

@end
