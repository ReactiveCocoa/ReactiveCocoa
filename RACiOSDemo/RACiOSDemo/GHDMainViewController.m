//
//  GHDMainViewController.m
//  RACiOSDemo
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "GHDMainViewController.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
#import "GHDMainView.h"

@interface GHDMainViewController ()
@property (nonatomic, strong) GHDMainView *view;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *label;
@end


@implementation GHDMainViewController


#pragma mark UIViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if(self == nil) return nil;
	
	[RACAbleSelf(self.text) subscribeNext:^(id x) {
		NSLog(@"%@", x);
	}];
	
	[[RACAbleSelf(self.text) 
		select:^(id x) {
			return [x uppercaseString]; 
		}]
		toProperty:RAC_KEYPATH_SELF(self.label) onObject:self];
	
	[self rac_bind:RAC_KEYPATH_SELF(self.view.label.text) to:RACAbleSelf(self.label)];
	
	return self;
}

- (void)loadView {
	self.view = [GHDMainView viewFromNib];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	
	// Even though iOS doesn't give us bindings like AppKit, we can fake them 
	// pretty easily using RAC.
	[self rac_bind:RAC_KEYPATH_SELF(self.text) to:self.view.textField.rac_textSubscribable];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}


#pragma mark API

@dynamic view;
@synthesize text;
@synthesize label;

@end
