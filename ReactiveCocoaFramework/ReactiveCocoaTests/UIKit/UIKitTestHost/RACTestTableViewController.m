//
//  RACTestTableViewController.m
//  ReactiveCocoa
//
//  Created by Syo Ikeda on 12/30/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACTestTableViewController.h"

@implementation RACTestTableViewController

- (instancetype)initWithStyle:(UITableViewStyle)style {
	self = [super initWithStyle:style];
	if (self == nil) return nil;

	_numberOfSections = 1;
	[self.tableView registerClass:UITableViewHeaderFooterView.class forHeaderFooterViewReuseIdentifier:[self.class description]];

	return self;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	UITableViewHeaderFooterView *headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:[self.class description]];
	return headerView;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	return [tableView dequeueReusableCellWithIdentifier:[self.class description]] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[self.class description]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.numberOfSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 10;
}

@end
