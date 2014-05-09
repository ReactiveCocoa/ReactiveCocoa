//
//  UIPickerViewRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Denis Mikhaylov on 06.04.14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import <objc/message.h>
#import "RACSignal.h"
#import "UIPickerView+RACChannelSupport.h"
#import "RACChannel.h"
#import "RACUIPickerViewTestDataSource.h"
#import "NSObject+RACSelectorSignal.h"
#import "RACTuple.h"

SpecBegin(UIPickerViewRACSupport)

describe(@"UIPickerView", ^{
	__block UIPickerView *pickerView;
	__block id <UIPickerViewDataSource> dataSource;
	beforeEach(^{
		dataSource = [[RACUIPickerViewTestDataSource alloc] init];
		pickerView = [[UIPickerView alloc] initWithFrame:CGRectZero];
		pickerView.dataSource = dataSource;
		expect(pickerView).notTo.beNil();
	});
	
	it(@"sends the index of the selected row to the channel when a row is selected in the given component", ^{
		__block NSInteger index = -1;
		[[pickerView
		  rac_channelForSelectedRowInComponent:0]
		  subscribeNext:^(NSNumber *row) {
			index = row.integerValue;
		  }];
		
		[pickerView.delegate pickerView:pickerView didSelectRow:1 inComponent:0];
		expect(index).to.equal(1);
	});
	
	it(@"does not send the index of the selected row to the channel when a row is selected in another component", ^{
		__block NSInteger index = -1;
		[[pickerView rac_channelForSelectedRowInComponent:0] subscribeNext:^(NSNumber *row) {
			index = row.integerValue;
		}];
		
		[pickerView.delegate pickerView:pickerView didSelectRow:1 inComponent:1];
		expect(index).to.equal(-1);
	});
	
//	it(@"selects a row at index sent to channel", ^{
//		__block NSInteger selectedRow = [pickerView selectedRowInComponent:0];
//		[[pickerView rac_channelForSelectedRowInComponent:0] sendNext:@1];
//		expect(selectedRow).to.equal(1);
//	});
});

SpecEnd

