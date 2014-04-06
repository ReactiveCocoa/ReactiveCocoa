//
//  RACUIPickerViewTestDataSource.m
//  ReactiveCocoa
//
//  Created by Denis Mikhaylov on 06.04.14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "RACUIPickerViewTestDataSource.h"

@implementation RACUIPickerViewTestDataSource 
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
	return 2;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
	return 2;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
	return @"";
}
@end
