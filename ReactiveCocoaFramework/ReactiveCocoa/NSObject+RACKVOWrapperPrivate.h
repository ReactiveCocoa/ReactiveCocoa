//
//  NSObject+RACKVOWrapperPrivate.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 1/15/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (RACKVOWrapperPrivate)

// Should only be manipulated while synchronized on the receiver.
@property (nonatomic, strong) NSMutableArray *RACKVOTrampolines;

// Remove the trampoline from the receiver.
//
// trampoline - The trampoline to add. Cannot be nil.
//
// This method is thread-safe.
- (void)rac_addKVOTrampoline:(RACKVOTrampoline *)trampoline;

// Removes the trampoline from the receiver. This does *not* stop the
// trampoline's observation.
//
// trampoline - The trampoline to remove. Can be nil.
//
// This method is thread-safe.
- (void)rac_removeKVOTrampoline:(RACKVOTrampoline *)trampoline;

@end
