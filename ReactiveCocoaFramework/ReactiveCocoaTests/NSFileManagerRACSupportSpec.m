//
//  NSFileManagerRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/18/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"
#import "NSFileManager+RACSupport.h"

SpecBegin(NSFileManagerRACSupport)

NSURL * (^createTestFile)(void) = ^ id {
	NSString *guid = [[NSProcessInfo processInfo] globallyUniqueString];
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:guid];
	BOOL success = [@"" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	if (!success) return nil;

	return [NSURL fileURLWithPath:path isDirectory:NO];
};

it(@"should get notified of file events", ^{
	NSURL *testFileURL = createTestFile();
	expect(testFileURL).notTo.beNil();

	__block NSUInteger eventsReceived = 0;
	RACDisposable *disposable = [[NSFileManager rac_watchForEventsForFileAtURL:testFileURL queue:dispatch_get_main_queue()] subscribeNext:^(id x) {
		expect(x).to.equal(testFileURL);
		eventsReceived++;
	}];

	BOOL success = [@"blah" writeToURL:testFileURL atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	expect(success).to.beTruthy();

	expect(eventsReceived).will.equal(1);

	success = [@"more blah" writeToURL:testFileURL atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	expect(success).to.beTruthy();

	expect(eventsReceived).will.equal(2);

	[disposable dispose];
});

it(@"should complete when the file's deleted", ^{
	NSURL *testFileURL = createTestFile();
	expect(testFileURL).notTo.beNil();

	__block BOOL completed = NO;
	RACDisposable *disposable = [[NSFileManager rac_watchForEventsForFileAtURL:testFileURL queue:dispatch_get_main_queue()] subscribeCompleted:^{
		completed = YES;
	}];

	NSFileManager *fileManager = [[NSFileManager alloc] init];
	BOOL success = [fileManager removeItemAtURL:testFileURL error:NULL];
	expect(success).to.beTruthy();

	expect(completed).will.beTruthy();

	[disposable dispose];
});

SpecEnd
