//
//  GHDUserViewController.h
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/13/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class GHUserAccount;


@interface GHDUserViewController : NSViewController

- (id)initWithUserAccount:(GHUserAccount *)user;

@end
