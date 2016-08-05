//
//  Data.swift
//  Rex
//
//  Created by Ilya Laryionau on 10/05/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa

extension Data {
    /// Read the data at the URL, sending the result or an error.
    public static func rex_data(contentsOf url: URL, options: Data.ReadingOptions = []) -> SignalProducer<Data, NSError> {
        return SignalProducer<Data, NSError> { observer, disposable in
            do {
                let data = try Data(contentsOf: url, options: options)
                observer.sendNext(data)
                observer.sendCompleted()
            } catch {
                observer.sendFailed(error as NSError)
            }
        }
    }
}

extension Data {
    /// Read the data at the URL, sending the result or an error.
    public static func rex_data(contentsOf url: URL, options: NSData.ReadingOptions = []) -> SignalProducer<NSData, NSError> {
        return Data.rex_data(contentsOf: url, options: options).map { $0 as NSData }
    }
}
