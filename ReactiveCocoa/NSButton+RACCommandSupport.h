//
//  NSButton+RACCommandSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class RACCommand;


@interface NSButton (RACCommandSupport)

- (void)addCommand:(RACCommand *)command;

@end
