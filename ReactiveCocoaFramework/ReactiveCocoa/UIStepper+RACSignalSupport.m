//
//  UIStepper+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 20/07/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UIStepper+RACSignalSupport.h"
#import "EXTKeyPathCoding.h"
#import "UIControl+RACSignalSupport.h"

@implementation UIStepper (RACSignalSupport)

- (RACBinding *)rac_valueBindingWithNilValue:(id)nilValue {
	return [self rac_bindingForControlEvents:UIControlEventValueChanged key:@keypath(self.value) primitive:YES nilValue:nilValue];
}

@end
