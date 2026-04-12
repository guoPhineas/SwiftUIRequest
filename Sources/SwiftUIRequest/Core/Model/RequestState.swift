//
//  RequestState.swift
//  SwiftUIRequest
//
//  Created by Phineas Guo on 2026/4/12.
//

import Foundation

/// Tracks request result and progress for a typed request.
public struct RequestState<Value: Decodable> {
    /// Decoded or raw payload returned by the request.
    public var payload: RequestPayload<Value>?
    /// HTTP status code from the response.
    public var responseCode: Int?
    /// Indicates whether a request is currently running.
    public var isLoading: Bool = false
    /// Human-readable description of the latest error, if any.
    public var errorDescription: String?

    /// Returns the decoded value when payload is `.decoded`.
    public var value: Value? {
        if case let .decoded(value) = payload { return value }
        return nil
    }

    /// Returns raw data when payload is `.raw`.
    public var rawData: Data? {
        if case let .raw(data) = payload { return data }
        return nil
    }

    /// Creates an empty request state.
    public init() {}
}
