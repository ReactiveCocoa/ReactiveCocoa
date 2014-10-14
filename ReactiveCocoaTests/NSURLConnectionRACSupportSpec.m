//
//  NSURLConnectionRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-01.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "NSURLConnection+RACSupport.h"
#import "RACSignal+Operations.h"
#import "RACTuple.h"

QuickSpecBegin(NSURLConnectionRACSupportSpec)

qck_it(@"should fetch a JSON file", ^{
	NSURL *fileURL = [[NSBundle bundleForClass:self.class] URLForResource:@"test-data" withExtension:@"json"];
	expect(fileURL).notTo(beNil());

	NSURLRequest *request = [NSURLRequest requestWithURL:fileURL];

	BOOL success = NO;
	NSError *error = nil;
	RACTuple *result = [[NSURLConnection rac_sendAsynchronousRequest:request] firstOrDefault:nil success:&success error:&error];
	expect(@(success)).to(beTruthy());
	expect(error).to(beNil());
	expect(result).to(beAKindOf(RACTuple.class));

	NSURLResponse *response = result.first;
	expect(response).to(beAKindOf(NSURLResponse.class));

	NSData *data = result.second;
	expect(data).to(beAKindOf(NSData.class));
	expect(data).to(equal([NSData dataWithContentsOfURL:fileURL]));
});

QuickSpecEnd
