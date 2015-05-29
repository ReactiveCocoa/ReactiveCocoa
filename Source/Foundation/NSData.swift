//
//  NSData.swift
//  Rex
//
//  Created by Ilya Laryionau on 10/05/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa

extension NSData {
    /// Read the data at the URL.
    /// Sends the data or the error.
    class func rex_dataWithContentsOfURL(url: NSURL, options: NSDataReadingOptions = NSDataReadingOptions.allZeros) -> SignalProducer<NSData, NSError> {
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
