//
//  UIImagePickerControllerRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Timur Kuchkarov on 17.04.14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "UIImagePickerController+RACSignalSupport.h"
#import "RACSignal.h"

SpecBegin(UIImagePickerControllerRACSupport)

describe(@"UIImagePickerController", ^{
	__block UIImagePickerController *imagePicker;
	
	beforeEach(^{
		imagePicker = [[UIImagePickerController alloc] init];
		expect(imagePicker).notTo.beNil();
	});
	
	it(@"sends the user info dictionary after confirmation", ^{
		__block NSDictionary *selectedImageUserInfo = nil;
		[imagePicker.rac_imageSelectedSignal subscribeNext:^(NSDictionary *userInfo) {
			selectedImageUserInfo = userInfo;
		}];
		
		NSDictionary *info = @{
			UIImagePickerControllerMediaType: @"public.image",
			UIImagePickerControllerMediaMetadata: @{}
		};
		[imagePicker.delegate imagePickerController:imagePicker didFinishPickingMediaWithInfo:info];
		expect(selectedImageUserInfo).to.equal(info);
	});
	
	it(@"cancels image picking process", ^{
		__block BOOL didSend = NO;
		__block BOOL didComplete = NO;
		[imagePicker.rac_imageSelectedSignal subscribeNext:^(NSDictionary *userInfo) {
			didSend = YES;
		} completed:^{
			didComplete = YES;
		}];
		
		[imagePicker.delegate imagePickerControllerDidCancel:imagePicker];
		expect(didSend).to.beFalsy();
		expect(didComplete).to.beTruthy();
	});
});

SpecEnd
