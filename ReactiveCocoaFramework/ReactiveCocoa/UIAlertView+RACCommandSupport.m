//
//  UIAlertView+RACCommandSupport.m
//  ReactiveCocoa
//
//  Created by Henrik Hodne on 6/16/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UIAlertView+RACCommandSupport.h"

#import <ReactiveCocoa/RACCommand.h>
#import <objc/runtime.h>

static void *UIAlertViewRACCommandKey = &UIAlertViewRACCommandKey;
static void *UIAlertViewDelegateKey = &UIAlertViewDelegateKey;

@interface RACUIAlertViewDelegate : NSObject <UIAlertViewDelegate>
@end

@implementation RACUIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	[alertView.rac_command execute:@(buttonIndex)];
}

@end

@implementation UIAlertView (RACCommandSupport)

- (RACCommand *)rac_command {
	return objc_getAssociatedObject(self, UIAlertViewRACCommandKey);
}

- (void)setRac_command:(RACCommand *)command {
	objc_setAssociatedObject(self, UIAlertViewRACCommandKey, command, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	if (command == nil) {
		objc_setAssociatedObject(self, UIAlertViewDelegateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		self.delegate = nil;
	} else {
		RACUIAlertViewDelegate *delegate = [[RACUIAlertViewDelegate alloc] init];
		objc_setAssociatedObject(self, UIAlertViewDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

		if (self.delegate != nil) NSLog(@"WARNING: UIAlertView.rac_command hijacks the alert view's existing delegate.");

		self.delegate = delegate;
	}

}

@end
