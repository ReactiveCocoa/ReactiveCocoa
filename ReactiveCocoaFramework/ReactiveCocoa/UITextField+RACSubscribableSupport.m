//
//  UITextField+RACSubscribableSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "UITextField+RACSubscribableSupport.h"
#import "UIControl+RACSubscribableSupport.h"
#import "RACSubscribable+Operations.h"


@implementation UITextField (RACSubscribableSupport)

- (RACSubscribable *)rac_textSubscribable {
	return [[self rac_subscribableForControlEvents:UIControlEventEditingChanged] select:^(id x) {
		return [x text];
	}];
}

@end
