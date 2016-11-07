#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface RACSwiftInvocationArguments : NSObject

@property(readonly, nonatomic) NSInteger count;

-(const char *)argumentTypeAt:(NSInteger)position;
-(void)copyArgumentAt:(NSInteger)position to:(void *)buffer;
-(NSString*)selectorStringAt:(NSInteger)position;

@end

@interface NSObject (RACObjCRuntimeUtilities)

/// Register a block which would be triggered when `selector` is called.
///
/// Warning: The callee is responsible for synchronization.
-(BOOL) _rac_setupInvocationObservationForSelector:(SEL)selector protocol:(nullable Protocol *)protocol receiver:(void (^)(RACSwiftInvocationArguments*)) receiver;

@end
NS_ASSUME_NONNULL_END
