//
//  UITextView+RACSubscribableSupport.h
//  Heading
//
//  Created by Cody Krieger on 5/18/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACSubscribable;

@interface UITextView (RACSubscribableSupport)

// Creates and returns a subscribable that sends the sender of the control event
// whenever one of the control events is triggered.
- (RACSubscribable *)rac_subscribableForControlEvents:(UIControlEvents)controlEvents;

// Creates and returns a subscribable for the text of the field.
- (RACSubscribable *)rac_textSubscribable;

@end
