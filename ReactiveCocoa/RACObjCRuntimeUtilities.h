#import <Foundation/Foundation.h>

typedef void (^rac_receiver_t)(void);

/// Register a block which would be triggered when `selector` is called.
///
/// Warning: The callee is responsible for synchronization.
BOOL RACRegisterBlockForSelector(NSObject *self, SEL selector, Protocol *protocol, rac_receiver_t receiver);
