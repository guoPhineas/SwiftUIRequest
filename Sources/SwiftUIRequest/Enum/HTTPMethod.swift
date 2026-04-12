//
//  HTTPMethod.swift
//  SwiftUIRequest
//
//  Created by Phineas Guo on 2026/4/12.
//

import Foundation

/// Supported HTTP request methods.
public enum HTTPMethod: String, Sendable, Equatable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
    case trace = "TRACE"
    case connect = "CONNECT"
}
