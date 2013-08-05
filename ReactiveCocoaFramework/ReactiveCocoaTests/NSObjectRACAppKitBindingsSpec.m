//
//  NSObjectRACAppKitBindingsSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-07-01.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACChannelExamples.h"

#import "EXTKeyPathCoding.h"
#import "NSObject+RACAppKitBindings.h"
#import "NSObject+RACDeallocating.h"
#import "RACChannel.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSignal+Operations.h"

SpecBegin(NSObjectRACAppKitBindings)

itShouldBehaveLike(RACViewChannelExamples, ^{
	return @{
		RACViewChannelExampleCreateViewBlock: ^{
			return [[NSTextField alloc] initWithFrame:NSZeroRect];
		},
		RACViewChannelExampleCreateTerminalBlock: ^(NSTextField *view) {
			return [view rac_channelToBinding:NSValueBinding];
		},
		RACViewChannelExampleKeyPath: @keypath(NSTextField.new, stringValue),
		RACViewChannelExampleSetViewTextBlock: ^(NSTextField *textField, NSString *text) {
			textField.stringValue = text;

			// Bindings don't actually trigger from programmatic modification. Do it
			// manually.
			NSDictionary *bindingInfo = [textField infoForBinding:NSValueBinding];
			[bindingInfo[NSObservedObjectKey] setValue:text forKeyPath:bindingInfo[NSObservedKeyPathKey]];
		}
	};
});

SpecEnd
