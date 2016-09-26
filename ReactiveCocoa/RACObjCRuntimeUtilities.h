#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef void (^rac_receiver_t)(void);

/// Register a block which would be triggered when `selector` is called.
///
/// Warning: The callee is responsible for synchronization.
BOOL RACRegisterBlockForSelector(NSObject *self, SEL selector, Protocol * _Nullable protocol, rac_receiver_t receiver);
NS_ASSUME_NONNULL_END
