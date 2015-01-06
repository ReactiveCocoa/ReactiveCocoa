//
//  RACTestUIButton.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-06-15.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

// Enables use of -sendActionsForControlEvents: in unit tests.
@interface RACTestUIButton : UIButton

+ (instancetype)button;

@end
