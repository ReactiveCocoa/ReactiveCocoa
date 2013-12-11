//
//  UIRefreshControl+RACSupport.h
//  ReactiveCocoa
//
//  Created by Dave Lee on 2013-10-17.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACCommand;
@class RACSignalGenerator;

@interface UIRefreshControl (RACSupport)

/// Subscribes to a signal from the given generator when the refresh control is
/// activated.
///
/// When the receiver is activated, -[RACSignalGenerator signalWithValue:] will
/// be invoked (with the sender as the argument), and the resulting signal will
/// be subscribed to. When the signal terminates, -endRefreshing will be invoked
/// automatically.
@property (nonatomic, strong) RACSignalGenerator *rac_refreshGenerator;

@end

@interface UIRefreshControl (RACSupportDeprecated)

/// Manipulate the RACCommand property associated with this refresh control.
///
/// When this refresh control is activated by the user, the command will be
/// executed. Upon completion or error of the execution signal, -endRefreshing
/// will be invoked.
@property (nonatomic, strong) RACCommand *rac_command;

@end
