//
//  NSText+RACSupport.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-03-08.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSText+RACSupport.h"
#import "EXTScope.h"
#import "NSObject+RACDescription.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSignal.h"
#import "RACSubscriber.h"

@implementation NSText (RACSupport)

- (RACSignal *)rac_textSignal {
	@unsafeify(self);
	return [[[[RACSignal
		create:^(id<RACSubscriber> subscriber) {
			@strongify(self);
			id observer = [NSNotificationCenter.defaultCenter addObserverForName:NSTextDidChangeNotification object:self queue:nil usingBlock:^(NSNotification *note) {
				[subscriber sendNext:note.object];
			}];

			[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
				[NSNotificationCenter.defaultCenter removeObserver:observer];
			}]];
		}]
		map:^(NSText *text) {
			return [text.string copy];
		}]
		startWith:[self.string copy]]
		setNameWithFormat:@"%@ -rac_textSignal", [self rac_description]];
}

@end
