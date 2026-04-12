//
//  RequestPreset.swift
//  SwiftUIRequest
//
//  Created by Phineas Guo on 2026/4/12.
//

import Foundation

/// Reusable request factory built from a configuration.
public struct RequestPreset: Sendable, Equatable {
    /// Shared configuration used to build requests.
    public var configuration: RequestConfiguration

    /// Creates a request preset with optional configuration.
    /// - Parameter configuration: Shared configuration used when building URL requests.
    public init(configuration: RequestConfiguration = RequestConfiguration()) {
        self.configuration = configuration
    }

    /// Builds a URLRequest by combining URL, method, preset headers, and ad-hoc headers.
    /// - Parameters:
    ///   - url: The base endpoint URL.
    ///   - method: The HTTP method to apply. Defaults to `GET`.
    ///   - headers: Per-request headers that override or supplement preset headers.
    ///   - body: The post request body.
    /// - Returns: A fully configured `URLRequest`, or `nil` if URL composition fails.
    public func makeRequest(for url: URL, method: HTTPMethod = .get, headers: [String: String] = [:], body: Data? = nil) -> URLRequest? {
        guard let finalURL = configuration.url(from: url) else { return nil }
        var request = URLRequest(url: finalURL)
        request.httpMethod = method.rawValue
        request.httpBody = body
        configuration.apply(to: &request)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }
}
