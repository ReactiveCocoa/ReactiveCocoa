//
//  UICollectionViewCellRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Kent Wong on 2013-10-04.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACAppDelegate.h"

#import "RACSignal.h"
#import "RACUnit.h"
#import "UICollectionReusableView+RACSignalSupport.h"

@interface TestCollectionViewController : UICollectionViewController
@end

SpecBegin(UICollectionReusableViewRACSupport)

__block UICollectionViewFlowLayout *collectionViewFlowLayout;
__block TestCollectionViewController *collectionViewController;

beforeEach(^{
	collectionViewFlowLayout = [[UICollectionViewFlowLayout alloc] init];
	CGSize screenSize = UIScreen.mainScreen.bounds.size;
	collectionViewFlowLayout.itemSize = CGSizeMake(screenSize.width, screenSize.height / 2);
	
	collectionViewController = [[TestCollectionViewController alloc] initWithCollectionViewLayout:collectionViewFlowLayout];
	expect(collectionViewController).notTo.beNil();
	
	[collectionViewController.collectionView registerClass:UICollectionViewCell.class forCellWithReuseIdentifier:NSStringFromClass(collectionViewController.class)];
	
	RACAppDelegate.delegate.window.rootViewController = collectionViewController;
	expect(collectionViewController.collectionView.visibleCells.count).will.beGreaterThan(0);
});

it(@"should send on rac_prepareForReuseSignal", ^{
	UICollectionViewCell *cell = collectionViewController.collectionView.visibleCells[0];
	
	__block NSUInteger invocationCount = 0;
	[cell.rac_prepareForReuseSignal subscribeNext:^(id value) {
		expect(value).to.equal(RACUnit.defaultUnit);
		++invocationCount;
	}];
	
	expect(invocationCount).to.equal(0);
	
	// The following two expectations will fail in the iOS 7 simulator, but pass on an iPad 4th gen device running iOS 7.
	// This appears to be a known issue with the iOS 7 simulator. See http://openradar.appspot.com/14973972
	// These tests will pass with iOS 6.0 and 6.1.
	if ([UIDevice.currentDevice.systemVersion compare:@"7.0" options:NSNumericSearch] == NSOrderedAscending ||
		(!TARGET_IPHONE_SIMULATOR && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)) {
		[collectionViewController.collectionView reloadData];
		expect(invocationCount).will.equal(1);
		
		[collectionViewController.collectionView reloadData];
		expect(invocationCount).will.equal(2);
	}
});

SpecEnd

@implementation TestCollectionViewController

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
	return [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass(self.class) forIndexPath:indexPath];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
	return 20;
}

@end
