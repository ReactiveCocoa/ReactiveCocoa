//
//  UICollectionReusableView+RACSupport.m
//  ReactiveCocoa
//
//  Created by Kent Wong on 2013-10-04.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UICollectionReusableView+RACSupport.h"
#import "NSObject+RACDescription.h"
#import "NSObject+RACSelectorSignal.h"
#import "RACSignal+Operations.h"
#import "RACUnit.h"
#import <objc/runtime.h>

@implementation UICollectionReusableView (RACSupport)

- (RACSignal *)rac_prepareForReuseSignal {
	RACSignal *signal = objc_getAssociatedObject(self, _cmd);
	if (signal != nil) return signal;
	
	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wdeprecated"

	signal = [[[self
		rac_signalForSelector:@selector(prepareForReuse)]
		// Can't break our RAC 2.x interface contract here.
		mapReplace:RACUnit.defaultUnit]
		setNameWithFormat:@"%@ -rac_prepareForReuseSignal", self.rac_description];

	#pragma clang diagnostic pop
	
	objc_setAssociatedObject(self, _cmd, signal, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	return signal;
}

@end
