//
//  RACAppDelegate.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface RACAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTextField *textField1;
@property (assign) IBOutlet NSButton *doMagicButton;
@property (assign) IBOutlet NSTextField *textField2;
@property (assign) IBOutlet NSTextField *matchesLabel;
@property (assign) IBOutlet NSButton *duplicateButton;

@end
