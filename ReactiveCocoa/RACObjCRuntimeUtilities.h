#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
IMP _rac_objc_msgForward();

@interface NSObject (RACObjCRuntimeUtilities)

/// Register a block which would be triggered when `selector` is called.
///
/// Warning: The callee is responsible for synchronization.
-(BOOL) _rac_setupInvocationObservationForSelector:(SEL)selector protocol:(nullable Protocol *)protocol argsReceiver:(void (^)(id)) receiverBlock;

/// Register a block which would be triggered when `selector` is called.
///
/// Warning: The callee is responsible for synchronization.
-(BOOL) _rac_setupInvocationObservationForSelector:(SEL)selector protocol:(nullable Protocol *)protocol receiver:(void (^)(void)) receiverBlock;

@end
NS_ASSUME_NONNULL_END
