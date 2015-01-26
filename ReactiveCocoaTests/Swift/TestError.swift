//
//  TestError.swift
//  ReactiveCocoa
//
//  Created by Almas Sapargali on 1/26/15.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import Foundation
import ReactiveCocoa

enum TestError {
	case Default
}

extension TestError: ErrorType {
	var nsError: NSError {
		return NSError(domain: "", code: 0, userInfo: nil)
	}
}
