//
//  UIControl+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "UIControl+RACSignalSupport.h"
#import "EXTScope.h"
#import "RACBinding+Private.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACObservablePropertySubject.h"
#import "RACSignal.h"
#import "RACSignal+Operations.h"
#import "RACSubscriber+Private.h"
#import "NSInvocation+RACTypeParsing.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"

@implementation UIControl (RACSignalSupport)

- (RACSignal *)rac_signalForControlEvents:(UIControlEvents)controlEvents {
	@weakify(self);

	return [[RACSignal
		createSignal:^(id<RACSubscriber> subscriber) {
			@strongify(self);

			[self addTarget:subscriber action:@selector(sendNext:) forControlEvents:controlEvents];
			[self.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				[subscriber sendCompleted];
			}]];

			return [RACDisposable disposableWithBlock:^{
				@strongify(self);
				[self removeTarget:subscriber action:@selector(sendNext:) forControlEvents:controlEvents];
			}];
		}]
		setNameWithFormat:@"%@ -rac_signalForControlEvents: %lx", [self rac_description], (unsigned long)controlEvents];
}

- (RACBinding *)rac_bindingForControlEvents:(UIControlEvents)controlEvents key:(NSString *)key nilValue:(id)nilValue {
	RACBinding *binding = [[RACBinding alloc] init];
	if (binding == nil) return nil;

	RACBinding *KVOBinding = [RACObservablePropertySubject propertyWithTarget:self keyPath:key nilValue:nilValue].binding;
	RACSignal *controlEventsSignal = [[self
		rac_signalForControlEvents:controlEvents]
		map:^(id sender) {
			return [sender valueForKey:key];
		}];

	binding.signal = [RACSignal merge:@[ controlEventsSignal, KVOBinding ]];
	binding.subscriber = KVOBinding;

	return binding;
}

@end
