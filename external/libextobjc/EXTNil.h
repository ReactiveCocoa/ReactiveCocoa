//
//  EXTNil.h
//  extobjc
//
//  Created by Justin Spahr-Summers on 2011-04-25.
//  Released into the public domain.
//

#import <Foundation/Foundation.h>

/**
 * Like \c NSNull, this class provides a singleton object that can be used to
 * represent a \c NULL or \c nil value. Unlike \c NSNull, this object behaves
 * more similarly to a \c nil object, responding to messages with "zero" values.
 * This eliminates the need for \c NSNull class or equality checks with
 * collections that need to contain null values.
 *
 * This class will pretend to be \c NSNull when queried for its class or
 * compared for equality, to keep compatibility with code that expects or uses
 * \c NSNull.
 *
 * @note Because this class does still behave like an object in some ways, it
 * will respond to certain \c NSObject protocol methods where an actually \c nil
 * object would not.
 */
@interface EXTNil : NSProxy {
    
}

/**
 * Returns the singleton \c EXTNil instance. This naming matches that of \c
 * NSNull -- \c nil as a method name is unusable because it is a language
 * keyword.
 */
+ (id)null;

@end
