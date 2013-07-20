//
//  UISlider+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 20/07/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UISlider+RACSignalSupport.h"
#import "EXTKeyPathCoding.h"
#import "UIControl+RACSignalSupport.h"

@implementation UISlider (RACSignalSupport)

- (RACBinding *)rac_valueBindingWithNilValue:(id)nilValue {
	return [self rac_bindingForControlEvents:UIControlEventValueChanged keyPath:@keypath(self.value) nilValue:nilValue];
}

@end
