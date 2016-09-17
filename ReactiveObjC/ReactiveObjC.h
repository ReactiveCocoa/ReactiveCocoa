//
//  ReactiveObjC.h
//  ReactiveObjC
//
//  Created by Josh Abernathy on 3/5/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Project version number for ReactiveObjC.
FOUNDATION_EXPORT double ReactiveObjCVersionNumber;

//! Project version string for ReactiveObjC.
FOUNDATION_EXPORT const unsigned char ReactiveObjCVersionString[];

#import <ReactiveObjC/EXTKeyPathCoding.h>
#import <ReactiveObjC/EXTScope.h>
#import <ReactiveObjC/NSArray+RACSequenceAdditions.h>
#import <ReactiveObjC/NSData+RACSupport.h>
#import <ReactiveObjC/NSDictionary+RACSequenceAdditions.h>
#import <ReactiveObjC/NSEnumerator+RACSequenceAdditions.h>
#import <ReactiveObjC/NSFileHandle+RACSupport.h>
#import <ReactiveObjC/NSNotificationCenter+RACSupport.h>
#import <ReactiveObjC/NSObject+RACDeallocating.h>
#import <ReactiveObjC/NSObject+RACLifting.h>
#import <ReactiveObjC/NSObject+RACPropertySubscribing.h>
#import <ReactiveObjC/NSObject+RACSelectorSignal.h>
#import <ReactiveObjC/NSOrderedSet+RACSequenceAdditions.h>
#import <ReactiveObjC/NSSet+RACSequenceAdditions.h>
#import <ReactiveObjC/NSString+RACSequenceAdditions.h>
#import <ReactiveObjC/NSString+RACSupport.h>
#import <ReactiveObjC/NSIndexSet+RACSequenceAdditions.h>
#import <ReactiveObjC/NSUserDefaults+RACSupport.h>
#import <ReactiveObjC/RACBehaviorSubject.h>
#import <ReactiveObjC/RACChannel.h>
#import <ReactiveObjC/RACCommand.h>
#import <ReactiveObjC/RACCompoundDisposable.h>
#import <ReactiveObjC/RACDelegateProxy.h>
#import <ReactiveObjC/RACDisposable.h>
#import <ReactiveObjC/RACEvent.h>
#import <ReactiveObjC/RACGroupedSignal.h>
#import <ReactiveObjC/RACKVOChannel.h>
#import <ReactiveObjC/RACMulticastConnection.h>
#import <ReactiveObjC/RACQueueScheduler.h>
#import <ReactiveObjC/RACQueueScheduler+Subclass.h>
#import <ReactiveObjC/RACReplaySubject.h>
#import <ReactiveObjC/RACScheduler.h>
#import <ReactiveObjC/RACScheduler+Subclass.h>
#import <ReactiveObjC/RACScopedDisposable.h>
#import <ReactiveObjC/RACSequence.h>
#import <ReactiveObjC/RACSerialDisposable.h>
#import <ReactiveObjC/RACSignal+Operations.h>
#import <ReactiveObjC/RACSignal.h>
#import <ReactiveObjC/RACStream.h>
#import <ReactiveObjC/RACSubject.h>
#import <ReactiveObjC/RACSubscriber.h>
#import <ReactiveObjC/RACSubscriptingAssignmentTrampoline.h>
#import <ReactiveObjC/RACTargetQueueScheduler.h>
#import <ReactiveObjC/RACTestScheduler.h>
#import <ReactiveObjC/RACTuple.h>
#import <ReactiveObjC/RACUnit.h>

#if TARGET_OS_WATCH
#elif TARGET_OS_IOS || TARGET_OS_TV
	#import <ReactiveObjC/UIBarButtonItem+RACCommandSupport.h>
	#import <ReactiveObjC/UIButton+RACCommandSupport.h>
	#import <ReactiveObjC/UICollectionReusableView+RACSignalSupport.h>
	#import <ReactiveObjC/UIControl+RACSignalSupport.h>
	#import <ReactiveObjC/UIGestureRecognizer+RACSignalSupport.h>
	#import <ReactiveObjC/UISegmentedControl+RACSignalSupport.h>
	#import <ReactiveObjC/UITableViewCell+RACSignalSupport.h>
	#import <ReactiveObjC/UITableViewHeaderFooterView+RACSignalSupport.h>
	#import <ReactiveObjC/UITextField+RACSignalSupport.h>
	#import <ReactiveObjC/UITextView+RACSignalSupport.h>

	#if TARGET_OS_IOS
		#import <ReactiveObjC/NSURLConnection+RACSupport.h>
		#import <ReactiveObjC/UIStepper+RACSignalSupport.h>
		#import <ReactiveObjC/UIDatePicker+RACSignalSupport.h>
		#import <ReactiveObjC/UIAlertView+RACSignalSupport.h>
		#import <ReactiveObjC/UIActionSheet+RACSignalSupport.h>
		#import <ReactiveObjC/MKAnnotationView+RACSignalSupport.h>
		#import <ReactiveObjC/UIImagePickerController+RACSignalSupport.h>
		#import <ReactiveObjC/UIRefreshControl+RACCommandSupport.h>
		#import <ReactiveObjC/UISlider+RACSignalSupport.h>
		#import <ReactiveObjC/UISwitch+RACSignalSupport.h>
	#endif
#elif TARGET_OS_MAC
	#import <ReactiveObjC/NSControl+RACCommandSupport.h>
	#import <ReactiveObjC/NSControl+RACTextSignalSupport.h>
	#import <ReactiveObjC/NSObject+RACAppKitBindings.h>
	#import <ReactiveObjC/NSText+RACSignalSupport.h>
	#import <ReactiveObjC/NSURLConnection+RACSupport.h>
#endif
