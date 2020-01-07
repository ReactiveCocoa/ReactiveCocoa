#import "MessageForwardingEntity.h"
#pragma GCC diagnostic ignored "-Wundeclared-selector"

@implementation MessageForwardingEntity

- (instancetype) init {
	if (self = [super init]) {
		self.hasInvoked = NO;
	}
	return self;
}

- (BOOL) respondsToSelector:(SEL)aSelector {
	if (aSelector == @selector(_rac_test_forwarding)) {
		return YES;
	}
	return [super respondsToSelector:aSelector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
	if (aSelector == @selector(_rac_test_forwarding)) {
		return [NSMethodSignature signatureWithObjCTypes:"v@:"];
	}
	return [super methodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
	if (anInvocation.selector == @selector(_rac_test_forwarding)) {
		[self setHasInvoked:YES];
		return;
	}
	return [super forwardInvocation:anInvocation];
}

@end
