// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Observation
import OSLog
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Property wrapper that requests, decodes, and exposes typed network data.
@MainActor
@propertyWrapper
public struct Request<Value: ResponseBaseModel> {
    private let store: RequestStore<Value>
    private let loader: @Sendable () async throws -> (Data, URLResponse)
    private let decoder: JSONDecoder
    private let fallbackToRaw: Bool
    private let errorHandler: (@Sendable (Error?, HTTPURLResponse?, Data?) -> Void)?

    /// Decoded value returned by the latest request.
    public var wrappedValue: Value? { store.state.value }
    /// Exposes the observable request store for state inspection in views.
    public var projectedValue: RequestState<Value> { store.state }
    /// HTTP status code for the latest response.
    public var responseCode: Int? { store.state.responseCode }
    /// Indicates whether the request is currently running.
    public var isLoading: Bool { store.state.isLoading }
    /// Latest request/decode error description.
    public var errorDescription: String? { store.state.errorDescription }
    /// Raw response bytes when decoding fallback is used.
    public var rawData: Data? { store.state.rawData }

    /// Creates a request wrapper from a `RequestModel` type.
    /// - Parameters:
    ///   - type: The model type that provides static request metadata.
    ///   - session: URL session used to execute the request.
    ///   - decoder: JSON decoder used for typed decoding.
    ///   - fallbackToRaw: Stores raw data when decoding fails if set to `true`.
    ///   - errorHandler: Optional closure invoked on URLSession errors or non-2xx responses.
    public init(_ type: Value.Type,
                session: URLSession = .shared,
                decoder: JSONDecoder = JSONDecoder(),
                fallbackToRaw: Bool = true,
                errorHandler: (@Sendable (Error?, HTTPURLResponse?, Data?) -> Void)? = nil) where Value: ResponseModel {
        self.init(type, configuration: RequestConfiguration(), session: session, decoder: decoder, fallbackToRaw: fallbackToRaw, errorHandler: errorHandler)
    }

    /// Creates a request wrapper from a `RequestModel` type and additional request configuration.
    /// - Parameters:
    ///   - type: The model type that provides static request metadata.
    ///   - configuration: Runtime query/header/auth configuration to merge into the request.
    ///   - session: URL session used to execute the request.
    ///   - decoder: JSON decoder used for typed decoding.
    ///   - fallbackToRaw: Stores raw data when decoding fails if set to `true`.
    ///   - errorHandler: Optional closure invoked on URLSession errors or non-2xx responses.
    public init(_ type: Value.Type,
                configuration: RequestConfiguration,
                session: URLSession = .shared,
                decoder: JSONDecoder = JSONDecoder(),
            fallbackToRaw: Bool = true,
            errorHandler: (@Sendable (Error?, HTTPURLResponse?, Data?) -> Void)? = nil) where Value: ResponseModel {
        self.store = RequestStore()
        self.decoder = decoder
        self.fallbackToRaw = fallbackToRaw
        self.errorHandler = errorHandler

        let requestURL = type.requestURL
        let requestMethod = type.requestMethod
        let requestHeaders = type.requestHeaders
        let requestBody = type.requestBody
        let preset = RequestPreset(configuration: configuration)

        self.loader = {
            guard let request = preset.makeRequest(for: requestURL, method: requestMethod, headers: requestHeaders, body: requestBody) else {
                throw URLError(.badURL)
            }
            return try await session.data(for: request)
        }
        let store = self.store
        let loader = self.loader
        let decoder = self.decoder
        let fallbackToRaw = self.fallbackToRaw
        let errorHandler = self.errorHandler
        Task {
            await Self.performFetch(store: store, loader: loader, decoder: decoder, fallbackToRaw: fallbackToRaw, errorHandler: errorHandler)
        }
    }

    /// Creates a request wrapper from an explicit URL, method, and headers.
    /// - Parameters:
    ///   - url: The endpoint URL.
    ///   - method: The HTTP method. Defaults to `GET`.
    ///   - headers: Additional request headers.
    ///   - session: URL session used to execute the request.
    ///   - decoder: JSON decoder used for typed decoding.
    ///   - fallbackToRaw: Stores raw data when decoding fails if set to `true`.
    ///   - errorHandler: Optional closure invoked on URLSession errors or non-2xx responses.
    public init(url: URL,
                method: HTTPMethod = .get,
                headers: [String: String] = [:],
                body: Data? = nil,
                session: URLSession = .shared,
                decoder: JSONDecoder = JSONDecoder(),
                fallbackToRaw: Bool = true,
                errorHandler: (@Sendable (Error?, HTTPURLResponse?, Data?) -> Void)? = nil) where Value: ResponseBaseModel{
        self.store = RequestStore()
        self.decoder = decoder
        self.fallbackToRaw = fallbackToRaw
        self.errorHandler = errorHandler
        self.loader = {
            var request = URLRequest(url: url)
            request.httpMethod = method.rawValue
            request.httpBody = body
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            return try await session.data(for: request)
        }
        let store = self.store
        let loader = self.loader
        let decoder = self.decoder
        let fallbackToRaw = self.fallbackToRaw
        let errorHandler = self.errorHandler
        Task {
            await Self.performFetch(store: store, loader: loader, decoder: decoder, fallbackToRaw: fallbackToRaw, errorHandler: errorHandler)
        }
    }

    /// Creates a request wrapper using a preset plus ad-hoc URL/method/headers.
    /// - Parameters:
    ///   - preset: Shared request preset containing reusable configuration.
    ///   - url: The endpoint URL.
    ///   - method: The HTTP method. Defaults to `GET`.
    ///   - headers: Additional request headers.
    ///   - body: The post request body.
    ///   - session: URL session used to execute the request.
    ///   - decoder: JSON decoder used for typed decoding.
    ///   - fallbackToRaw: Stores raw data when decoding fails if set to `true`.
    ///   - errorHandler: Optional closure invoked on URLSession errors or non-2xx responses.
    public init(preset: RequestPreset,
                url: URL,
                method: HTTPMethod = .get,
                headers: [String: String] = [:],
                body: Data? = nil,
                session: URLSession = .shared,
                decoder: JSONDecoder = JSONDecoder(),
                fallbackToRaw: Bool = true,
                errorHandler: (@Sendable (Error?, HTTPURLResponse?, Data?) -> Void)? = nil) where Value: ResponseBaseModel {
        self.store = RequestStore()
        self.decoder = decoder
        self.fallbackToRaw = fallbackToRaw
        self.errorHandler = errorHandler
        self.loader = {
            guard let request = preset.makeRequest(for: url, method: method, headers: headers, body: body) else {
                throw URLError(.badURL)
            }
            return try await session.data(for: request)
        }
        let store = self.store
        let loader = self.loader
        let decoder = self.decoder
        let fallbackToRaw = self.fallbackToRaw
        let errorHandler = self.errorHandler
        Task {
            await Self.performFetch(store: store, loader: loader, decoder: decoder, fallbackToRaw: fallbackToRaw, errorHandler: errorHandler)
        }
    }

    /// Returns a closure that triggers a reload when called.
    public var reloadAction: () -> Void {
        let store = self.store
        let loader = self.loader
        let decoder = self.decoder
        let fallbackToRaw = self.fallbackToRaw
        let errorHandler = self.errorHandler
        return {
            Task {
                await Self.performFetch(store: store, loader: loader, decoder: decoder, fallbackToRaw: fallbackToRaw, errorHandler: errorHandler)
            }
        }
    }

    /// Reloads data asynchronously.
    public func reload() async {
        await Self.performFetch(store: store, loader: loader, decoder: decoder, fallbackToRaw: fallbackToRaw, errorHandler: errorHandler)
    }

    /// Reloads data by spawning an async task.
    public func reload() {
        Task {
            await reload()
        }
    }

    /// Performs the request, updates state, decodes payload, and optionally stores raw data on decode failure.
    /// - Parameters:
    ///   - store: Mutable request store that receives loading and payload updates.
    ///   - loader: Asynchronous loader that returns response bytes and metadata.
    ///   - decoder: Decoder used to decode `Value` from the response payload.
    ///   - fallbackToRaw: Stores raw response bytes when decode fails if set to `true`.
    ///   - errorHandler: Optional closure invoked on URLSession errors or non-2xx responses.
    private static func performFetch(store: RequestStore<Value>,
                                     loader: @escaping @Sendable () async throws -> (Data, URLResponse),
                                     decoder: JSONDecoder,
                                     fallbackToRaw: Bool,
                                     errorHandler: (@Sendable (Error?, HTTPURLResponse?, Data?) -> Void)?) async {
        store.beginLoading()
        defer { store.finishLoading() }
        #if DEBUG
        // If the response model confirms to Mockable and it's on debug environment, return a mock data.
        if let mockType = Value.self as? Mockable.Type {
            guard let mockModel = mockType.mockData as? Value else {
                store.setResponseCode(500)
                store.setError("Cannot cast mock data to \(Value.self). Actual: \(type(of: mockType.mockData))")
                return
            }
            store.setMockData(mockModel)
            store.setResponseCode(200)
            store.setError(nil)
            logger.info("Using mock data of \(type(of: Value.self))")
            return
        }
        #endif
        do {
            let (data, response) = try await loader()
            let httpResponse = response as? HTTPURLResponse
            store.setResponseCode(httpResponse?.statusCode)
            if let httpResponse, !(200...299).contains(httpResponse.statusCode) {
                errorHandler?(nil, httpResponse, data)
            }
            do {
                let decoded = try decoder.decode(Value.self, from: data)
                store.setDecoded(decoded)
                store.setError(nil)
            } catch {
                if fallbackToRaw {
                    store.setRaw(data)
                    store.setError(error.localizedDescription)
                } else {
                    store.setError(error.localizedDescription)
                }
            }
        } catch {
            errorHandler?(error, nil, nil)
            store.setError(String(describing: error))
        }
    }
}

public extension Request {
    /// Creates a request wrapper from a model type and a preset.
    /// - Parameters:
    ///   - type: The model type that provides static request metadata.
    ///   - preset: Shared request preset containing reusable configuration.
    ///   - session: URL session used to execute the request.
    ///   - decoder: JSON decoder used for typed decoding.
    ///   - fallbackToRaw: Stores raw data when decoding fails if set to `true`.
    ///   - errorHandler: Optional closure invoked on URLSession errors or non-2xx responses.
    init(_ type: Value.Type,
         preset: RequestPreset,
         session: URLSession = .shared,
         decoder: JSONDecoder = JSONDecoder(),
         fallbackToRaw: Bool = true,
         errorHandler: (@Sendable (Error?, HTTPURLResponse?, Data?) -> Void)? = nil) where Value: ResponseModel {
        self.init(type, configuration: preset.configuration, session: session, decoder: decoder, fallbackToRaw: fallbackToRaw, errorHandler: errorHandler)
    }
}


