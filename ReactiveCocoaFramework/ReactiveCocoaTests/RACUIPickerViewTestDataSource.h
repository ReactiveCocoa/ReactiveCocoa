//
//  RACUIPickerViewTestDataSource.h
//  ReactiveCocoa
//
//  Created by Denis Mikhaylov on 06.04.14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface RACUIPickerViewTestDataSource : NSObject <UIPickerViewDataSource>
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView;
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component;
@end
