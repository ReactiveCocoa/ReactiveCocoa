//
//  NSView+GHDExtensions.h
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/13/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSView (GHDExtensions)

+ (id)ghd_viewFromNib;
+ (id)ghd_viewFromNibNamed:(NSString *)nibName;

@end
