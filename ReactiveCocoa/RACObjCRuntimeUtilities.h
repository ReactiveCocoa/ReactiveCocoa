#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN
/// A trampoline of `objc_setAssociatedObject` that is made to circumvent the
/// reference counting calls in the imported version in Swift.
void _rac_objc_setAssociatedObject(const void* object, const void* key, id _Nullable value, objc_AssociationPolicy policy);

@interface NSObject (RACObjCRuntimeUtilities)

/// Register a block which would be triggered when `selector` is called.
///
/// Warning: The callee is responsible for synchronization.
-(BOOL) _rac_setupInvocationObservationForSelector:(SEL)selector protocol:(nullable Protocol *)protocol receiver:(void (^)(void)) receiver;

@end
NS_ASSUME_NONNULL_END
