//
//  UITextView+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/18/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import "UITextView+RACSignalSupport.h"
#import "EXTScope.h"
#import "NSObject+RACDeallocating.h"
#import "RACSignal+Operations.h"
#import "RACTuple.h"
#import "NSObject+RACDescription.h"
#import "NSNotificationCenter+RACSupport.h"
#import <objc/runtime.h>

@implementation UITextView (RACSignalSupport)

- (RACSignal *)rac_textSignal {
	@weakify(self);
    RACSignal *noteSignal = [[[NSNotificationCenter defaultCenter] rac_addObserverForName:UITextViewTextDidChangeNotification object:self] map:^id(NSNotification *note) {
        UITextView *tv = note.object;
        return tv.text;
    }];
	RACSignal *signal = [[[[RACSignal
                            defer:^{
                                @strongify(self);
                                return [RACSignal return:self.text];
                            }]
                           concat:noteSignal]
                          takeUntil:self.rac_willDeallocSignal]
                         setNameWithFormat:@"%@ -rac_textSignal", [self rac_description]];
    
    
	return signal;
}

@end
