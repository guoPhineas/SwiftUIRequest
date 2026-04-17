//
//  RequestStore.swift
//  SwiftUIRequest
//
//  Created by Phineas Guo on 2026/4/12.
//

import Foundation
import OSLog

/// Observable storage for request state updates.
@MainActor
@Observable
public final class RequestStore<Value: ResponseBaseModel> {
    /// Current request state.
    public private(set) var state = RequestState<Value>()

    /// Creates an empty request store.
    public init() {}

    /// Marks the request as loading and clears previous error text.
    func beginLoading() {
        state.isLoading = true
        state.errorOccurred = nil
    }

    /// Marks the request as finished.
    func finishLoading() {
        state.isLoading = false
    }

    /// Saves the HTTP response code.
    /// - Parameter code: The status code extracted from `HTTPURLResponse`.
    func setResponseCode(_ code: Int?) {
        state.responseCode = code
    }

    /// Saves a decoded payload.
    /// - Parameter value: The decoded model value.
    func setDecoded(_ value: Value) {
        state.payload = .decoded(value)
    }

    /// Saves a raw payload.
    /// - Parameter data: Raw response bytes when typed decoding is not available.
    func setRaw(_ data: Data) {
        state.payload = .raw(data)
    }

    /// Saves an error description.
    /// - Parameter error: Errors that occur during operation.
    func setError(_ error: RequestError?) {
        state.errorOccurred = error
        guard let error = error else { return }
        logger.error("An error that occur during operation: \(String(error.localizedDescription))")
    }
    
    /// Save the mock data and mark it mock
    /// - Parameter mockData: The mock data.
    func setMockData(_ mockData: Value){
        self.setDecoded(mockData)
        state.isMock = true
    }
}
