//
//  RequestConfiguration.swift
//  SwiftUIRequest
//
//  Created by Phineas Guo on 2026/4/12.
//

import Foundation

/// Runtime configuration applied to request creation.
public struct RequestConfiguration: Sendable, Equatable {
    /// Additional HTTP headers merged into generated requests.
    public var headers: [String: String]
    /// Query items appended to the base URL.
    public var queryItems: [URLQueryItem]
    /// Optional bearer token for `Authorization` header.
    public var authenticationToken: String?

    /// Creates a request configuration.
    /// - Parameters:
    ///   - headers: Additional HTTP headers merged into generated requests.
    ///   - queryItems: Query items appended to the base URL.
    ///   - authenticationToken: Optional bearer token added to the `Authorization` header.
    public init(headers: [String: String] = [:], queryItems: [URLQueryItem] = [], authenticationToken: String? = nil) {
        self.headers = headers
        self.queryItems = queryItems
        self.authenticationToken = authenticationToken
    }

    /// Builds a final URL by appending query items to `baseURL`.
    /// - Parameter baseURL: The base URL before query items are merged.
    /// - Returns: The final URL with merged query items, or `nil` if URL components cannot be resolved.
    public func url(from baseURL: URL) -> URL? {
        guard !queryItems.isEmpty else { return baseURL }
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
        let existing = components.queryItems ?? []
        components.queryItems = existing + queryItems
        return components.url
    }

    /// Applies configured headers and optional bearer token to a URLRequest.
    /// - Parameter request: The request to mutate with headers and authentication.
    public func apply(to request: inout URLRequest) {
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if let authenticationToken, !authenticationToken.isEmpty {
            request.setValue("Bearer \(authenticationToken)", forHTTPHeaderField: "Authorization")
        }
    }
}
