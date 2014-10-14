//
//  UIActionSheetRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Dave Lee on 2013-06-22.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACSignal.h"
#import "RACSignal+Operations.h"
#import "UIActionSheet+RACSignalSupport.h"

QuickSpecBegin(UIActionSheetRACSupportSpec)

qck_describe(@"-rac_buttonClickedSignal", ^{
	__block UIActionSheet *actionSheet;

	qck_beforeEach(^{
		actionSheet = [[UIActionSheet alloc] init];
		[actionSheet addButtonWithTitle:@"Button 0"];
		[actionSheet addButtonWithTitle:@"Button 1"];
		expect(actionSheet).notTo(beNil());
	});

	qck_it(@"should send the index of the clicked button", ^{
		__block NSNumber *index = nil;
		[actionSheet.rac_buttonClickedSignal subscribeNext:^(NSNumber *i) {
			index = i;
		}];

		[actionSheet.delegate actionSheet:actionSheet clickedButtonAtIndex:1];
		expect(index).to(equal(@1));
	});
});

QuickSpecEnd
