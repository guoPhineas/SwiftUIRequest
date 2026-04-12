//
//  ResponseModel.swift
//  SwiftUIRequest
//
//  Created by Phineas Guo on 2026/4/12.
//

import Foundation

/// Describes a decodable API model with static request metadata.
public protocol ResponseModel: ResponseBaseModel {
    /// The base URL used to request this model.
    static var requestURL: URL { get }
    /// The HTTP method used for this model request.
    static var requestMethod: HTTPMethod { get }
    /// Default HTTP headers applied to this model request.
    static var requestHeaders: [String: String] { get }
    /// The post request body
    static var requestBody: Data? { get }
}

public extension ResponseModel {
    /// The default HTTP method (`GET`).
    static var requestMethod: HTTPMethod { .get }
    /// The default request headers (empty).
    static var requestHeaders: [String: String] { [:] }
    /// The default request body (empty).
    static var requestBody: Data? { nil }
}
