//
//  RACNil.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACNil.h"

#import <objc/runtime.h>


@implementation RACNil


#pragma mark API

+ (id)nill {
	static dispatch_once_t onceToken;
	static RACNil *nill = nil;
	dispatch_once(&onceToken, ^{
		nill = [[self alloc] init];
	});
	
	return nill;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    NSUInteger returnLength = [[invocation methodSignature] methodReturnLength];
    if (!returnLength) {
        return;
    }
	
    char buffer[returnLength];
    memset(buffer, 0, returnLength);
	
    [invocation setReturnValue:buffer];
}

// from https://github.com/jspahrsummers/libextobjc/blob/master/extobjc/Modules/EXTRuntimeExtensions.m
Class *ext_copyClassList (unsigned *count) {
    // get the number of classes registered with the runtime
    int classCount = objc_getClassList(NULL, 0);
    if (!classCount) {
        if (count)
            *count = 0;
		
        return NULL;
    }
	
    // allocate space for them plus NULL
    Class *allClasses = (Class *)malloc(sizeof(Class) * (classCount + 1));
    if (!allClasses) {
        fprintf(stderr, "ERROR: Could allocate memory for all classes\n");
        if (count)
            *count = 0;
		
        return NULL;
    }
	
    // and then actually pull the list of the class objects
    classCount = objc_getClassList(allClasses, classCount);
    allClasses[classCount] = NULL;
	
    @autoreleasepool {
        // weed out classes that do weird things when reflected upon
        for (int i = 0;i < classCount;) {
            Class class = allClasses[i];
            BOOL keep = YES;
			
            if (keep)
                keep &= class_respondsToSelector(class, @selector(methodSignatureForSelector:));
			
            if (keep) {
                if (class_respondsToSelector(class, @selector(isProxy)))
                    keep &= ![class isProxy];
            }
			
            if (!keep) {
                if (--classCount > i) {
                    memmove(allClasses + i, allClasses + i + 1, (classCount - i) * sizeof(*allClasses));
                }
				
                continue;
            }
			
            ++i;
        }
    }
	
    if (count)
        *count = (unsigned)classCount;
	
    return allClasses;
}

NSMethodSignature *ext_globalMethodSignatureForSelector (SEL aSelector) {
    // set up a simplistic cache to avoid repeatedly scouring every class in the
    // runtime
    static const size_t selectorCacheLength = 1 << 8;
    static const uintptr_t selectorCacheMask = (selectorCacheLength - 1);
    static void * volatile selectorCache[selectorCacheLength];
	
    const char *cachedType = selectorCache[(uintptr_t)aSelector & selectorCacheMask];
    if (cachedType) {
        return [NSMethodSignature signatureWithObjCTypes:cachedType];
    }
	
    unsigned classCount = 0;
    Class *classes = ext_copyClassList(&classCount);
    if (!classes)
        return nil;
	
    NSMethodSignature *signature = nil;
	
    /*
     * set up an autorelease pool in case any Cocoa classes invoke +initialize
     * during this process
     */
    @autoreleasepool {
        for (unsigned i = 0;i < classCount;++i) {
            Class cls = classes[i];
            Method method;
			
            method = class_getInstanceMethod(cls, aSelector);
            if (!method)
                method = class_getClassMethod(cls, aSelector);
			
            if (method) {
                const char *type = method_getTypeEncoding(method);
                uintptr_t cacheLocation = ((uintptr_t)aSelector & selectorCacheMask);
				
                // this doesn't need to be a barrier, and we don't care whether
                // it succeeds, since our only goal is to make things faster in
                // the future
                OSAtomicCompareAndSwapPtr(selectorCache[cacheLocation], (void *)type, selectorCache + cacheLocation);
				
                signature = [NSMethodSignature signatureWithObjCTypes:type];
                break;
            }
        }
    }
	
    free(classes);
    return signature;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return ext_globalMethodSignatureForSelector(selector);
}

- (BOOL)respondsToSelector:(SEL)selector {
    return NO;
}

- (BOOL)conformsToProtocol:(Protocol *)protocol {
    return NO;
}

- (NSUInteger)hash {
    return 0;
}

- (BOOL)isEqual:(id)obj {
    return NO;
}

- (BOOL)isKindOfClass:(Class)class {
    return NO;
}

- (BOOL)isMemberOfClass:(Class)class {
    return NO;
}

@end
