//
//  RACScopedDisposable.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/28/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACDisposable.h"


@interface RACScopedDisposable : RACDisposable

+ (id)scopedDisposableWithDisposable:(RACDisposable *)disposable;

@end
