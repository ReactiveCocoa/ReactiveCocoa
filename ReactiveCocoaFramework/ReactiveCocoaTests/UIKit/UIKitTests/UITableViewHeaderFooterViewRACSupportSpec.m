//
//  UITableViewHeaderFooterViewRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Syo Ikeda on 12/30/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACAppDelegate.h"
#import "RACTestTableViewController.h"

#import "RACSignal.h"
#import "RACUnit.h"
#import "UITableViewHeaderFooterView+RACSignalSupport.h"

SpecBegin(UITableViewHeaderFooterViewRACSupportSpec)

__block RACTestTableViewController *tableViewController;

beforeEach(^{
	tableViewController = [[RACTestTableViewController alloc] initWithStyle:UITableViewStylePlain];
	expect(tableViewController).notTo.beNil();

	RACAppDelegate.delegate.window.rootViewController = tableViewController;
	expect([tableViewController.tableView headerViewForSection:0]).notTo.beNil();
});

it(@"should send on rac_prepareForReuseSignal", ^{
	UITableViewHeaderFooterView *headerView = [tableViewController.tableView headerViewForSection:0];

	__block NSUInteger invocationCount = 0;
	[headerView.rac_prepareForReuseSignal subscribeNext:^(id value) {
		expect(value).to.equal(RACUnit.defaultUnit);
		invocationCount++;
	}];

	expect(invocationCount).to.equal(0);

	void (^scrollToSectionForReuse)(NSInteger) = ^(NSInteger section) {
		NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:section];
		[tableViewController.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
	};

	scrollToSectionForReuse(tableViewController.tableView.numberOfSections - 1);
	expect(invocationCount).will.equal(1);

	scrollToSectionForReuse(0);
	expect(invocationCount).will.equal(2);
});

SpecEnd
