//
//  NSDictionary+RACSupport.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACDeprecated.h"

@class RACSequence;

@interface NSDictionary (RACSupport)

@end

@interface NSDictionary (RACSupportDeprecated)

@property (nonatomic, copy, readonly) RACSequence *rac_sequence RACDeprecated("Use -rac_signal instead");
@property (nonatomic, copy, readonly) RACSequence *rac_keySequence RACDeprecated("Use -rac_keySignal instead");
@property (nonatomic, copy, readonly) RACSequence *rac_valueSequence RACDeprecated("Use -rac_valueSignal instead");

@end
