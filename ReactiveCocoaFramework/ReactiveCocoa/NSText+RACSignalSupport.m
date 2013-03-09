//
//  NSText+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-03-08.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSText+RACSignalSupport.h"
#import "EXTScope.h"
#import "RACDisposable.h"
#import "RACSignal.h"
#import "RACSubscriber.h"

@implementation NSText (RACSignalSupport)

- (RACSignal *)rac_textSignal {
	@unsafeify(self);
	return [[[[RACSignal
		createSignal:^(id<RACSubscriber> subscriber) {
			@strongify(self);
			id observer = [NSNotificationCenter.defaultCenter addObserverForName:NSTextDidChangeNotification object:self queue:nil usingBlock:^(NSNotification *note) {
				[subscriber sendNext:note.object];
			}];

			return [RACDisposable disposableWithBlock:^{
				[NSNotificationCenter.defaultCenter removeObserver:observer];
			}];
		}]
		startWith:self]
		map:^(NSText *text) {
			return [text.string copy];
		}]
		setNameWithFormat:@"%@ -rac_textSignal", self];
}

@end
