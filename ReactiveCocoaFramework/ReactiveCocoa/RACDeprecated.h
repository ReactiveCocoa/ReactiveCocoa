//
//  RACDeprecated.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-18.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

// Define this constant before importing any ReactiveCocoa headers to
// temporarily silence RAC 3.0 deprecation warnings.
//
// Please remember to fix them up at some point, because any deprecated APIs
// will be removed by the time RAC hits 4.0.
#ifdef WE_PROMISE_TO_MIGRATE_TO_REACTIVECOCOA_3_0
	#define RACDeprecated(MSG)
#else
	#define RACDeprecated(MSG) __attribute((deprecated(MSG " (See RACDeprecated.h to silence this warning)")))
#endif
