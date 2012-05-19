//
//  UITextView+RACSubscribableSupport.h
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/18/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACSubscribable;

@interface UITextView (RACSubscribableSupport)

// Creates and returns a subscribable that sends the sender of the delegate 
// method whenever it is triggered.
- (RACSubscribable *)rac_subscribableForDelegateMethod:(SEL)method;

// Creates and returns a subscribable for the text of the field.
- (RACSubscribable *)rac_textSubscribable;

@end
