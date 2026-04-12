// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Observation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Describes a decodable API model without any request metadatas.
public protocol ResponseBaseModel: Decodable { }

/// Describes a decodable API model with static request metadata.
public protocol ResponseModel: ResponseBaseModel {
    /// The base URL used to request this model.
    static var requestURL: URL { get }
    /// The HTTP method used for this model request.
    static var requestMethod: HTTPMethod { get }
    /// Default HTTP headers applied to this model request.
    static var requestHeaders: [String: String] { get }
}

public extension ResponseModel {
    /// The default HTTP method (`GET`).
    static var requestMethod: HTTPMethod { .get }
    /// The default request headers (empty).
    static var requestHeaders: [String: String] { [:] }
}

/// Represents either a decoded value or raw response bytes.
public enum RequestPayload<Value: Decodable> {
    /// Successfully decoded typed value.
    case decoded(Value)
    /// Raw response data when decoding fails and fallback is enabled.
    case raw(Data)
}

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
    /// - Returns: A fully configured `URLRequest`, or `nil` if URL composition fails.
    public func makeRequest(for url: URL, method: HTTPMethod = .get, headers: [String: String] = [:]) -> URLRequest? {
        guard let finalURL = configuration.url(from: url) else { return nil }
        var request = URLRequest(url: finalURL)
        request.httpMethod = method.rawValue
        configuration.apply(to: &request)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }
}

/// Observable storage for request state updates.
@MainActor
@Observable
public final class RequestStore<Value: Decodable> {
    /// Current request state.
    public private(set) var state = RequestState<Value>()

    /// Creates an empty request store.
    public init() {}

    /// Marks the request as loading and clears previous error text.
    func beginLoading() {
        state.isLoading = true
        state.errorDescription = nil
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
    /// - Parameter message: Human-readable error details.
    func setError(_ message: String?) {
        state.errorDescription = message
    }
}

/// Property wrapper that requests, decodes, and exposes typed network data.
@MainActor
@propertyWrapper
public struct Request<Value: Decodable> {
    @ObservationIgnored private let store: RequestStore<Value>
    @ObservationIgnored private let loader: @Sendable () async throws -> (Data, URLResponse)
    @ObservationIgnored private let decoder: JSONDecoder
    @ObservationIgnored private let fallbackToRaw: Bool

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
    public init(_ type: Value.Type,
                session: URLSession = .shared,
                decoder: JSONDecoder = JSONDecoder(),
                fallbackToRaw: Bool = true) where Value: ResponseModel {
        self.init(type, configuration: RequestConfiguration(), session: session, decoder: decoder, fallbackToRaw: fallbackToRaw)
    }

    /// Creates a request wrapper from a `RequestModel` type and additional request configuration.
    /// - Parameters:
    ///   - type: The model type that provides static request metadata.
    ///   - configuration: Runtime query/header/auth configuration to merge into the request.
    ///   - session: URL session used to execute the request.
    ///   - decoder: JSON decoder used for typed decoding.
    ///   - fallbackToRaw: Stores raw data when decoding fails if set to `true`.
    public init(_ type: Value.Type,
                configuration: RequestConfiguration,
                session: URLSession = .shared,
                decoder: JSONDecoder = JSONDecoder(),
                fallbackToRaw: Bool = true) where Value: ResponseModel {
        self.store = RequestStore()
        self.decoder = decoder
        self.fallbackToRaw = fallbackToRaw

        let requestURL = type.requestURL
        let requestMethod = type.requestMethod
        let requestHeaders = type.requestHeaders
        let preset = RequestPreset(configuration: configuration)

        self.loader = {
            guard let request = preset.makeRequest(for: requestURL, method: requestMethod, headers: requestHeaders) else {
                throw URLError(.badURL)
            }
            return try await session.data(for: request)
        }
        let store = self.store
        let loader = self.loader
        let decoder = self.decoder
        let fallbackToRaw = self.fallbackToRaw
        Task {
            await Self.performFetch(store: store, loader: loader, decoder: decoder, fallbackToRaw: fallbackToRaw)
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
    public init(url: URL,
                method: HTTPMethod = .get,
                headers: [String: String] = [:],
                session: URLSession = .shared,
                decoder: JSONDecoder = JSONDecoder(),
                fallbackToRaw: Bool = true) where Value: ResponseBaseModel{
        self.store = RequestStore()
        self.decoder = decoder
        self.fallbackToRaw = fallbackToRaw
        self.loader = {
            var request = URLRequest(url: url)
            request.httpMethod = method.rawValue
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            return try await session.data(for: request)
        }
        let store = self.store
        let loader = self.loader
        let decoder = self.decoder
        let fallbackToRaw = self.fallbackToRaw
        Task {
            await Self.performFetch(store: store, loader: loader, decoder: decoder, fallbackToRaw: fallbackToRaw)
        }
    }

    /// Creates a request wrapper using a preset plus ad-hoc URL/method/headers.
    /// - Parameters:
    ///   - preset: Shared request preset containing reusable configuration.
    ///   - url: The endpoint URL.
    ///   - method: The HTTP method. Defaults to `GET`.
    ///   - headers: Additional request headers.
    ///   - session: URL session used to execute the request.
    ///   - decoder: JSON decoder used for typed decoding.
    ///   - fallbackToRaw: Stores raw data when decoding fails if set to `true`.
    public init(preset: RequestPreset,
                url: URL,
                method: HTTPMethod = .get,
                headers: [String: String] = [:],
                session: URLSession = .shared,
                decoder: JSONDecoder = JSONDecoder(),
                fallbackToRaw: Bool = true) where Value: ResponseBaseModel {
        self.store = RequestStore()
        self.decoder = decoder
        self.fallbackToRaw = fallbackToRaw
        self.loader = {
            guard let request = preset.makeRequest(for: url, method: method, headers: headers) else {
                throw URLError(.badURL)
            }
            return try await session.data(for: request)
        }
        let store = self.store
        let loader = self.loader
        let decoder = self.decoder
        let fallbackToRaw = self.fallbackToRaw
        Task {
            await Self.performFetch(store: store, loader: loader, decoder: decoder, fallbackToRaw: fallbackToRaw)
        }
    }

    /// Returns a closure that triggers a reload when called.
    public var reloadAction: () -> Void {
        let store = self.store
        let loader = self.loader
        let decoder = self.decoder
        let fallbackToRaw = self.fallbackToRaw
        return {
            Task {
                await Self.performFetch(store: store, loader: loader, decoder: decoder, fallbackToRaw: fallbackToRaw)
            }
        }
    }

    /// Reloads data asynchronously.
    public func reload() async {
        await Self.performFetch(store: store, loader: loader, decoder: decoder, fallbackToRaw: fallbackToRaw)
    }

    /// Reloads data by spawning an async task.
    public func reload() {
        Task {
            await Self.performFetch(store: store, loader: loader, decoder: decoder, fallbackToRaw: fallbackToRaw)
        }
    }

    /// Performs the request, updates state, decodes payload, and optionally stores raw data on decode failure.
    /// - Parameters:
    ///   - store: Mutable request store that receives loading and payload updates.
    ///   - loader: Asynchronous loader that returns response bytes and metadata.
    ///   - decoder: Decoder used to decode `Value` from the response payload.
    ///   - fallbackToRaw: Stores raw response bytes when decode fails if set to `true`.
    private static func performFetch(store: RequestStore<Value>,
                                     loader: @escaping @Sendable () async throws -> (Data, URLResponse),
                                     decoder: JSONDecoder,
                                     fallbackToRaw: Bool) async {
        store.beginLoading()
        defer { store.finishLoading() }

        do {
            let (data, response) = try await loader()
            store.setResponseCode((response as? HTTPURLResponse)?.statusCode)
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
    init(_ type: Value.Type,
         preset: RequestPreset,
         session: URLSession = .shared,
         decoder: JSONDecoder = JSONDecoder(),
         fallbackToRaw: Bool = true) where Value: ResponseModel {
        self.init(type, configuration: preset.configuration, session: session, decoder: decoder, fallbackToRaw: fallbackToRaw)
    }
}

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


extension Array: ResponseBaseModel where Element: ResponseBaseModel {
    
}
