//
//  UISegmentedControl+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 20/07/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UISegmentedControl+RACSignalSupport.h"
#import "EXTKeyPathCoding.h"
#import "UIControl+RACSignalSupport.h"

@implementation UISegmentedControl (RACSignalSupport)

- (id)rac_selectedSegmentIndexBindingWithNilValue:(id)nilValue {
	return [self rac_bindingForControlEvents:UIControlEventValueChanged keyPath:@keypath(self.selectedSegmentIndex) nilValue:nilValue];
}

@end
