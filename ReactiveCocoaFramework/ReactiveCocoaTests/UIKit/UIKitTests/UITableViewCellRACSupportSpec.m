//
//  UITableViewCellRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-07-23.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACAppDelegate.h"

#import "RACSignal.h"
#import "RACUnit.h"
#import "UITableViewCell+RACSignalSupport.h"

@interface TestTableViewController : UITableViewController
@end

SpecBegin(UITableViewCellRACSupport)

__block TestTableViewController *tableViewController;

beforeEach(^{
	tableViewController = [[TestTableViewController alloc] initWithStyle:UITableViewStylePlain];
	expect(tableViewController).notTo.beNil();

	RACAppDelegate.delegate.window.rootViewController = tableViewController;
	expect(tableViewController.tableView.visibleCells.count).will.beGreaterThan(0);
});

it(@"should send on rac_prepareForReuseSignal", ^{
	UITableViewCell *cell = tableViewController.tableView.visibleCells[0];
	
	__block NSUInteger invocationCount = 0;
	[cell.rac_prepareForReuseSignal subscribeNext:^(id value) {
		expect(value).to.equal(RACUnit.defaultUnit);
		invocationCount++;
	}];

	expect(invocationCount).to.equal(0);

	[tableViewController.tableView reloadData];
	expect(invocationCount).will.equal(1);

	[tableViewController.tableView reloadData];
	expect(invocationCount).will.equal(2);
});

SpecEnd

@implementation TestTableViewController

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	return [tableView dequeueReusableCellWithIdentifier:[self.class description]] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[self.class description]];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 10;
}

@end
