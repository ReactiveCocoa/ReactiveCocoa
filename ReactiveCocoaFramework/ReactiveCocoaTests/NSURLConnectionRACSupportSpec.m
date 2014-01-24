//
//  NSURLConnectionRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-01.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSURLConnection+RACSupport.h"
#import "RACSignal+Operations.h"
#import "RACTuple.h"

SpecBegin(NSURLConnectionRACSupport)

it(@"should fetch a JSON file", ^{
	NSURL *fileURL = [[NSBundle bundleForClass:self.class] URLForResource:@"test-data" withExtension:@"json"];
	expect(fileURL).notTo.beNil();

	NSURLRequest *request = [NSURLRequest requestWithURL:fileURL];

	BOOL success = NO;
	NSError *error = nil;
	RACTuple *result = [[NSURLConnection rac_sendAsynchronousRequest:request] firstOrDefault:nil success:&success error:&error];
	expect(success).to.beTruthy();
	expect(error).to.beNil();
	expect(result).to.beKindOf(RACTuple.class);

	RACTupleUnpack(NSURLResponse *response, NSData *data) = result;
	expect(response).to.beKindOf(NSURLResponse.class);
	expect(data).to.beKindOf(NSData.class);
	expect(data).to.equal([NSData dataWithContentsOfURL:fileURL]);
});

SpecEnd
