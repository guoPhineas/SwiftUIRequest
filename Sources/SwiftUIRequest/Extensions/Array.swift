//
//  File.swift
//  SwiftUIRequest
//
//  Created by Phineas Guo on 2026/4/12.
//

import Foundation


/// Allows a top-level array payload to reuse request metadata from its element model.
extension Array: ResponseModel where Element: ResponseModel {
    /// Uses the element type's endpoint as the array request URL.
    public static var requestURL: URL {
        Element.requestURL
    }

    /// Uses the element type's HTTP method.
    public static var requestMethod: HTTPMethod {
        Element.requestMethod
    }

    /// Uses the element type's default headers.
    public static var requestHeaders: [String: String] {
        Element.requestHeaders
    }
}

/// The base model for top-level array payload.
extension Array: ResponseBaseModel where Element: ResponseBaseModel {
    
}

/// Allows a top-level array payload to using mock data.
extension Array: Mockable where Element: Mockable&ResponseBaseModel {
    public static var mockData: any ResponseBaseModel {
        [Element.mockData as! Element]
    }
    
}
