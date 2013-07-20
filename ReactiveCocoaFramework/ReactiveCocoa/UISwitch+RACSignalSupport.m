//
//  UISwitch+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 20/07/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UISwitch+RACSignalSupport.h"
#import "EXTKeyPathCoding.h"
#import "UIControl+RACSignalSupport.h"

@implementation UISwitch (RACSignalSupport)

- (RACBinding *)rac_onBindingWithNilValue:(id)nilValue {
	return [self rac_bindingForControlEvents:UIControlEventValueChanged keyPath:@keypath(self.on) nilValue:nilValue];
}

@end
