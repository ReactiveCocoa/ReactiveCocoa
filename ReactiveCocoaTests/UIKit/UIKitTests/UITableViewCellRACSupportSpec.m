//
//  UITableViewCellRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-07-23.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACAppDelegate.h"
#import "RACTestTableViewController.h"

#import "RACSignal.h"
#import "RACUnit.h"
#import "UITableViewCell+RACSignalSupport.h"

QuickSpecBegin(UITableViewCellRACSupportSpec)

__block RACTestTableViewController *tableViewController;

qck_beforeEach(^{
	tableViewController = [[RACTestTableViewController alloc] initWithStyle:UITableViewStylePlain];
	expect(tableViewController).notTo(beNil());

	RACAppDelegate.delegate.window.rootViewController = tableViewController;
	expect(tableViewController.tableView.visibleCells.count).toEventually(beGreaterThan(0));
});

qck_it(@"should send on rac_prepareForReuseSignal", ^{
	UITableViewCell *cell = tableViewController.tableView.visibleCells[0];
	
	__block NSUInteger invocationCount = 0;
	[cell.rac_prepareForReuseSignal subscribeNext:^(id value) {
		expect(value).to(equal(RACUnit.defaultUnit));
		invocationCount++;
	}];

	expect(invocationCount).to(equal(@0));

	[tableViewController.tableView reloadData];
	expect(invocationCount).toEventually(equal(@1));

	[tableViewController.tableView reloadData];
	expect(invocationCount).toEventually(equal(@2));
});

QuickSpecEnd
