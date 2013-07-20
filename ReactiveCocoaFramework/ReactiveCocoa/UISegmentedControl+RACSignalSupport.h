//
//  UISegmentedControl+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 20/07/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACBinding;

@interface UISegmentedControl (RACSignalSupport)

// Creates and returns a RACBinding that sends the receiver's currently selected
// segment's index on subscription and whenever UIControlEventValueChanged is
// fired and sets the selected segment index to the values it receives. If it
// receives `nil`, it sets the selected segment index to `nilValue` instead.
//
// Note that this differs from other RACBindings as it will not react to changes
// triggered from code regardless of what triggered the changes.
- (RACBinding *)rac_selectedSegmentIndexBindingWithNilValue:(id)nilValue;

@end
