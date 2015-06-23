//
//  UIButtonRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Ash Furrow on 2013-06-06.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>
#import "UITableViewCell+RACSignalSupport.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"

QuickSpecBegin(UITableViewCellRACSupportSpec)

qck_it(@"should not have any problem when use RACCell marco", ^{
	UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"TEST"];
	RACSubject *subjectA = [RACSubject subject];
	RACSubject *subjectB = [RACSubject subject];
	RACCell(cell, textLabel.text) = subjectA;
	[subjectA sendNext:@"15"];
	expect(cell.textLabel.text).to(equal(@"15"));
	[cell prepareForReuse];

	RACCell(cell, textLabel.text) = subjectB;
	[subjectB sendNext:@"20"];
	expect(cell.textLabel.text).to(equal(@"20"));
	[subjectA sendNext:@"30"];
	expect(cell.textLabel.text).notTo(equal(@"30"));
	
});

QuickSpecEnd
