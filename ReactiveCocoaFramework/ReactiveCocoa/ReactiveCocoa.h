//
//  ReactiveCocoa.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/5/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "EXTKeyPathCoding.h"
#import "NSArray+RACSupport.h"
#import "NSData+RACSupport.h"
#import "NSDictionary+RACSupport.h"
#import "NSEnumerator+RACSupport.h"
#import "NSFileHandle+RACSupport.h"
#import "NSNotificationCenter+RACSupport.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACLifting.h"
#import "NSObject+RACPropertySubscribing.h"
#import "NSObject+RACSelectorSignal.h"
#import "NSOrderedSet+RACSupport.h"
#import "NSSet+RACSupport.h"
#import "NSString+RACSupport.h"
#import "NSURLConnection+RACSupport.h"
#import "RACAction.h"
#import "RACChannel.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACDynamicSignalGenerator.h"
#import "RACEvent.h"
#import "RACGroupedSignal.h"
#import "RACKVOChannel.h"
#import "RACPromise.h"
#import "RACQueueScheduler.h"
#import "RACQueuedSignalGenerator.h"
#import "RACScheduler.h"
#import "RACScopedDisposable.h"
#import "RACSerialDisposable.h"
#import "RACSignal.h"
#import "RACSignal+Operations.h"
#import "RACSignalGenerator.h"
#import "RACSignalGenerator+Operations.h"
#import "RACSubject.h"
#import "RACSubscriber.h"
#import "RACSubscriptingAssignmentTrampoline.h"
#import "RACTargetQueueScheduler.h"
#import "RACTestScheduler.h"
#import "RACTuple.h"
#import "RACUnit.h"

#ifdef WE_PROMISE_TO_MIGRATE_TO_REACTIVECOCOA_3_0
	#import "RACBehaviorSubject.h"
	#import "RACCommand.h"
	#import "RACMulticastConnection.h"
	#import "RACReplaySubject.h"
	#import "RACSequence.h"
	#import "RACStream.h"
#endif

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
	#import "UIActionSheet+RACSupport.h"
	#import "UIAlertView+RACSupport.h"
	#import "UIBarButtonItem+RACSupport.h"
	#import "UIButton+RACSupport.h"
	#import "UICollectionReusableView+RACSupport.h"
	#import "UIControl+RACSupport.h"
	#import "UIDatePicker+RACSupport.h"
	#import "UIGestureRecognizer+RACSupport.h"
	#import "UISegmentedControl+RACSupport.h"
	#import "UISlider+RACSupport.h"
	#import "UIStepper+RACSupport.h"
	#import "UISwitch+RACSupport.h"
	#import "UITableViewCell+RACSupport.h"
	#import "UITextField+RACSupport.h"
	#import "UITextView+RACSupport.h"
#elif TARGET_OS_MAC
	#import "NSControl+RACSupport.h"
	#import "NSObject+RACAppKitBindings.h"
	#import "NSText+RACSupport.h"
#endif
