//
//  UIDatePicker+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 20/07/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UIDatePicker+RACSignalSupport.h"
#import "EXTKeyPathCoding.h"
#import "UIControl+RACSignalSupport.h"

@implementation UIDatePicker (RACSignalSupport)

- (RACBinding *)rac_dateBindingWithNilValue:(id)nilValue {
	return [self rac_bindingForControlEvents:UIControlEventValueChanged key:@keypath(self.date) primitive:NO nilValue:nilValue];
}

@end
