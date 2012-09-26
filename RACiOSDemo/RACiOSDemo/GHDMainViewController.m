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

@property (nonatomic, copy) NSString *text2;
@property (nonatomic, copy) NSString *label2;
@end


@implementation GHDMainViewController


#pragma mark UIViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if(self == nil) return nil;
	
	[RACAble(self.text) subscribeNext:^(id x) {
		NSLog(@"text: %@", x);
	}];
    
    [RACAble(self.text2) subscribeNext:^(id x) {
        NSLog(@"text2: %@", x);
    }];
	
	[[RACAble(self.text) 
		select:^(id x) {
			return [x uppercaseString]; 
		}]
		toProperty:RAC_KEYPATH_SELF(self.label) onObject:self];
    
    [[RACAble(self.text2)
        select:^id(id x) {
            return [x lowercaseString];
        }]
        toProperty:RAC_KEYPATH_SELF(self.label2) onObject:self];
	
	[self rac_bind:RAC_KEYPATH_SELF(self.view.label.text) to:RACAble(self.label)];
	[self rac_bind:RAC_KEYPATH_SELF(self.view.label2.text) to:RACAble(self.label2)];
	
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
    [self rac_bind:RAC_KEYPATH_SELF(self.text2) to:self.view.textView.rac_textSubscribable];
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
@synthesize text2;
@synthesize label2;

@end
