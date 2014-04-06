//
//  UIPickerView+RACChannelSupport.h
//  ReactiveCocoa
//
//  Created by Denis Mikhaylov on 06.04.14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACChannelTerminal;

@interface UIPickerView (RACChannelSupport)
- (RACChannelTerminal *)rac_channelForSelectedRowInComponent:(NSInteger)component;
@end
