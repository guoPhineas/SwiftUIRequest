//
//  File.swift
//  SwiftUIRequest
//
//  Created by Phineas Guo on 2026/4/14.
//

import Foundation

/// A protocol that confirming model mockable
public protocol Mockable where Self: ResponseBaseModel{
    /// Mock data
    ///
    /// Request session will return a random data. If the array has only one element, return itself.
    static var mockData: ResponseBaseModel { get }
}
