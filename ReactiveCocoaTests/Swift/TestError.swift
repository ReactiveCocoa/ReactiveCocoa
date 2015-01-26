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
	case Empty
	case WithCode(Int)
}

extension TestError: ErrorType {
	var nsError: NSError {
		switch self {
		case .Empty:
			return NSError(domain: "", code: 0, userInfo: nil)
		case let .WithCode(code):
			return NSError(domain: "", code: code, userInfo: nil)
		}
	}
}
