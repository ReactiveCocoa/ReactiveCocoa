//
//  NSObjectRACAppKitBindingsSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-07-01.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACChannelExamples.h"

#import <ReactiveCocoa/EXTKeyPathCoding.h>
#import "NSObject+RACAppKitBindings.h"

QuickSpecBegin(NSObjectRACAppKitBindingsSpec)

qck_itBehavesLike(RACViewChannelExamples, ^{
	return @{
		RACViewChannelExampleCreateViewBlock: ^{
			return [[NSSlider alloc] initWithFrame:NSZeroRect];
		},
		RACViewChannelExampleCreateTerminalBlock: ^(NSSlider *view) {
			return [view rac_channelToBinding:NSValueBinding];
		},
		RACViewChannelExampleKeyPath: @keypath(NSSlider.new, objectValue),
		RACViewChannelExampleSetViewValueBlock: ^(NSSlider *view, NSNumber *value) {
			view.objectValue = value;

			// Bindings don't actually trigger from programmatic modification. Do it
			// manually.
			NSDictionary *bindingInfo = [view infoForBinding:NSValueBinding];
			[bindingInfo[NSObservedObjectKey] setValue:value forKeyPath:bindingInfo[NSObservedKeyPathKey]];
		}
	};
});

QuickSpecEnd
