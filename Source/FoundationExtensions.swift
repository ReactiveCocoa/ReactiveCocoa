//
//  FoundationExtensions.swift
//  Rex
//
//  Created by Ilya Laryionau on 10/05/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCococa

extension NSData {
    /// Read the data at the URL.
    /// Sends the data or the error.
    class func rac_dataWithContentsOfURL(url: NSURL, options: NSDataReadingOptions = NSDataReadingOptions.allZeros) -> SignalProducer<NSData, NSError> {
        return SignalProducer<NSData, NSError> { observer, disposable in
            var error: NSError?
            if let data = NSData(contentsOfURL: url, options: options, error: &error) {
                sendNext(observer, data)
                sendCompleted(observer)
            } else {
                sendError(observer, error ?? NSError())
            }
        }
    }
}

extension NSUserDefaults {
    /// Sends value of key when the value is changed
    func rac_signalForKey(key: String) -> Signal<AnyObject?, NoError> {
        let (signal, observer) = Signal<AnyObject?, NoError>.pipe()
        
        // send initial value
        let initial: AnyObject? = self.objectForKey(UserDefaultsKeywordsKey)
        sendNext(observer, initial)

        // observe other values
        NSNotificationCenter.defaultCenter().rac_notifications(name: NSUserDefaultsDidChangeNotification, object: self).observe(next: { notification in
            let value: AnyObject? = self.objectForKey(key)
            
            sendNext(observer, value)
        }, completed: {
            sendCompleted(observer)
        })

        return signal
    }
}