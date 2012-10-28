//
//  UITextField+RACSubscribableSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "UITextField+RACSubscribableSupport.h"
#import "RACSubscribable.h"
#import "UIControl+RACSubscribableSupport.h"

@implementation UITextField (RACSubscribableSupport)

- (RACSubscribable *)rac_textSubscribable {
	return [[[self rac_subscribableForControlEvents:UIControlEventEditingChanged] startWith:self] select:^(UITextField *x) {
		return x.text;
	}];
}

@end
