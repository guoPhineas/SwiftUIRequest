// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Observation
import OSLog
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Property wrapper that requests, decodes, and exposes typed network data.
///
/// Unlike `Request`, `Requestable` does not automatically start a request during initialization.
/// Call `request(with:)` or `request(headers:body:)` to trigger a request.
@MainActor
@propertyWrapper
public struct Requestable<Request: RequestBaseModel, Response: ResponseBaseModel> {
    private let store: RequestStore<Response>
    private let loader: @Sendable () async throws -> (Data, URLResponse)
    private let requestBuilder: @Sendable (Data?, [String: String]?) throws -> URLRequest
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fallbackToRaw: Bool
    private let errorHandler: (@Sendable (Error?, HTTPURLResponse?, Data?) -> Void)?

    private func makeHTTPBody(from body: Request?) throws -> Data? {
        guard let body else { return nil }
        if let data = body as? Data {
            return data
        }
        return try encoder.encode(body)
    }

    /// Decoded value returned by the latest request.
    public var wrappedValue: Response? { store.state.value }
    /// Exposes the observable request store for state inspection in views.
    public var projectedValue: RequestState<Response> { store.state }
    /// HTTP status code for the latest response.
    public var responseCode: Int? { store.state.responseCode }
    /// Indicates whether the request is currently running.
    public var isLoading: Bool { store.state.isLoading }
    /// Latest request/decode error.
    public var errorOccurred: RequestError? { store.state.errorOccurred }
    /// Raw response bytes when decoding fallback is used.
    public var rawData: Data? { store.state.rawData }

    /// Creates a request wrapper from a payload type plus a response model type.
    ///
    /// Note: This initializer does not start the request automatically.
    /// - Parameters:
    ///   - payload: The request body model type.
    ///   - response: The response model type that provides static request metadata when it conforms to `ResponseModel`.
    ///   - session: URL session used to execute the request.
    ///   - encoder: JSON encoder used for request body encoding in `request(with:)`.
    ///   - decoder: JSON decoder used for typed decoding.
    ///   - fallbackToRaw: Stores raw data when decoding fails if set to `true`.
    ///   - errorHandler: Optional closure invoked on URLSession errors or non-2xx responses.
    public init(payload: Request.Type,
                response type: Response.Type,
                session: URLSession = .shared,
                encoder: JSONEncoder = JSONEncoder(),
                decoder: JSONDecoder = JSONDecoder(),
                fallbackToRaw: Bool = true,
                errorHandler: (@Sendable (Error?, HTTPURLResponse?, Data?) -> Void)? = nil) where Response: ResponseModel {
        self.init(payload: payload, response: type, configuration: RequestConfiguration(), session: session, encoder: encoder, decoder: decoder, fallbackToRaw: fallbackToRaw, errorHandler: errorHandler)
    }
    
    /// Creates a request wrapper from a payload type plus an explicit URL.
    ///
    /// Note: This initializer does not start the request automatically.
    /// - Parameters:
    ///   - payload: The model type that provides static request payload metadata.
    ///   - response: The response model type.
    ///   - session: URL session used to execute the request.
    ///   - encoder: JSON encoder used for request body encoding in `request(with:)`.
    ///   - decoder: JSON decoder used for typed decoding.
    ///   - fallbackToRaw: Stores raw data when decoding fails if set to `true`.
    ///   - errorHandler: Optional closure invoked on URLSession errors or non-2xx responses.
    public init(payload: Request.Type,
                response type: Response.Type,
                url: URL,
                method: HTTPMethod,
                headers: [String: String] = [:],
                body: Data? = nil,
                session: URLSession = .shared,
                encoder: JSONEncoder = JSONEncoder(),
                decoder: JSONDecoder = JSONDecoder(),
                fallbackToRaw: Bool = true,
                errorHandler: (@Sendable (Error?, HTTPURLResponse?, Data?) -> Void)? = nil) where Response: ResponseBaseModel {
        self.init(url: url,
                  method: method,
                  headers: headers,
                  body: body,
                  session: session,
                  encoder: encoder,
                  decoder: decoder,
                  fallbackToRaw: fallbackToRaw,
                  errorHandler: errorHandler)
    }
    
    /// Creates a request wrapper from a payload type plus an explicit URL.
    ///
    /// Note: This initializer does not start the request automatically.
    /// - Parameters:
    ///   - payload: The model type that provides static request payload metadata.
    ///   - session: URL session used to execute the request.
    ///   - encoder: JSON encoder used for request body encoding in `request(with:)`.
    ///   - decoder: JSON decoder used for typed decoding.
    ///   - fallbackToRaw: Stores raw data when decoding fails if set to `true`.
    ///   - errorHandler: Optional closure invoked on URLSession errors or non-2xx responses.
    public init(payload: Request.Type,
                url: URL,
                method: HTTPMethod,
                headers: [String: String] = [:],
                body: Data? = nil,
                session: URLSession = .shared,
                encoder: JSONEncoder = JSONEncoder(),
                decoder: JSONDecoder = JSONDecoder(),
                fallbackToRaw: Bool = true,
                errorHandler: (@Sendable (Error?, HTTPURLResponse?, Data?) -> Void)? = nil) where Response: ResponseBaseModel {
        self.init(url: url,
                  method: method,
                  headers: headers,
                  body: body,
                  session: session,
                  encoder: encoder,
                  decoder: decoder,
                  fallbackToRaw: fallbackToRaw,
                  errorHandler: errorHandler)
    }

    /// Creates a request wrapper from a payload type plus a response model type and additional request configuration.
    ///
    /// Note: This initializer does not start the request automatically.
    /// - Parameters:
    ///   - payload: The request body model type.
    ///   - response: The response model type that provides static request metadata when it conforms to `ResponseModel`.
    ///   - configuration: Runtime query/header/auth configuration to merge into the request.
    ///   - session: URL session used to execute the request.
    ///   - encoder: JSON encoder used for request body encoding in `request(with:)`.
    ///   - decoder: JSON decoder used for typed decoding.
    ///   - fallbackToRaw: Stores raw data when decoding fails if set to `true`.
    ///   - errorHandler: Optional closure invoked on URLSession errors or non-2xx responses.
    public init(payload: Request.Type,
                response type: Response.Type,
                configuration: RequestConfiguration,
                session: URLSession = .shared,
                encoder: JSONEncoder = JSONEncoder(),
                decoder: JSONDecoder = JSONDecoder(),
            fallbackToRaw: Bool = true,
            errorHandler: (@Sendable (Error?, HTTPURLResponse?, Data?) -> Void)? = nil) where Response: ResponseModel {
        self.store = RequestStore()
        self.session = session
        self.encoder = encoder
        self.decoder = decoder
        self.fallbackToRaw = fallbackToRaw
        self.errorHandler = errorHandler

        let requestURL = type.requestURL
        let requestMethod = type.requestMethod
        let requestHeaders = type.requestHeaders
        let requestBody = type.requestBody
        let preset = RequestPreset(configuration: configuration)

        self.requestBuilder = { overrideBody, overrideHeaders in
            let finalBody = overrideBody ?? requestBody

            let headersToUse: [String: String]
            if let overrideHeaders, !overrideHeaders.isEmpty {
                headersToUse = overrideHeaders
            } else {
                headersToUse = requestHeaders
            }

            guard let request = preset.makeRequest(for: requestURL, method: requestMethod, headers: headersToUse, body: finalBody) else {
                throw URLError(.badURL)
            }
            return request
        }

        let requestBuilder = self.requestBuilder
        self.loader = {
            let request = try requestBuilder(nil, nil)
            return try await session.data(for: request)
        }
    }

    /// Creates a request wrapper from an explicit URL, method, and headers.
    ///
    /// Note: This initializer does not start the request automatically.
    /// - Parameters:
    ///   - url: The endpoint URL.
    ///   - method: The HTTP method. Defaults to `GET`.
    ///   - headers: Additional request headers.
    ///   - session: URL session used to execute the request.
    ///   - encoder: JSON encoder used for request body encoding in `request(with:)`.
    ///   - decoder: JSON decoder used for typed decoding.
    ///   - fallbackToRaw: Stores raw data when decoding fails if set to `true`.
    ///   - errorHandler: Optional closure invoked on URLSession errors or non-2xx responses.
    public init(url: URL,
                method: HTTPMethod,
                headers: [String: String] = [:],
                body: Data? = nil,
                session: URLSession = .shared,
                encoder: JSONEncoder = JSONEncoder(),
                decoder: JSONDecoder = JSONDecoder(),
                fallbackToRaw: Bool = true,
                errorHandler: (@Sendable (Error?, HTTPURLResponse?, Data?) -> Void)? = nil) where Response: ResponseBaseModel{
        self.store = RequestStore()
        self.session = session
        self.encoder = encoder
        self.decoder = decoder
        self.fallbackToRaw = fallbackToRaw
        self.errorHandler = errorHandler

        let baseHeaders = headers
        self.requestBuilder = { overrideBody, overrideHeaders in
            var request = URLRequest(url: url)
            request.httpMethod = method.rawValue
            request.httpBody = overrideBody ?? body

            let headersToUse: [String: String]
            if let overrideHeaders, !overrideHeaders.isEmpty {
                headersToUse = overrideHeaders
            } else {
                headersToUse = baseHeaders
            }

            for (key, value) in headersToUse {
                request.setValue(value, forHTTPHeaderField: key)
            }
            return request
        }

        let requestBuilder = self.requestBuilder
        self.loader = {
            let request = try requestBuilder(nil, nil)
            return try await session.data(for: request)
        }
    }

    /// Creates a request wrapper using a preset plus ad-hoc URL/method/headers.
    ///
    /// Note: This initializer does not start the request automatically.
    /// - Parameters:
    ///   - preset: Shared request preset containing reusable configuration.
    ///   - url: The endpoint URL.
    ///   - method: The HTTP method. Defaults to `GET`.
    ///   - headers: Additional request headers.
    ///   - body: The post request body.
    ///   - session: URL session used to execute the request.
    ///   - encoder: JSON encoder used for request body encoding in `request(with:)`.
    ///   - decoder: JSON decoder used for typed decoding.
    ///   - fallbackToRaw: Stores raw data when decoding fails if set to `true`.
    ///   - errorHandler: Optional closure invoked on URLSession errors or non-2xx responses.
    public init(preset: RequestPreset,
                url: URL,
                method: HTTPMethod,
                headers: [String: String] = [:],
                body: Data? = nil,
                session: URLSession = .shared,
                encoder: JSONEncoder = JSONEncoder(),
                decoder: JSONDecoder = JSONDecoder(),
                fallbackToRaw: Bool = true,
                errorHandler: (@Sendable (Error?, HTTPURLResponse?, Data?) -> Void)? = nil) where Response: ResponseBaseModel {
        self.store = RequestStore()
        self.session = session
        self.encoder = encoder
        self.decoder = decoder
        self.fallbackToRaw = fallbackToRaw
        self.errorHandler = errorHandler

        let baseHeaders = headers
        self.requestBuilder = { overrideBody, overrideHeaders in
            let headersToUse: [String: String]
            if let overrideHeaders, !overrideHeaders.isEmpty {
                headersToUse = overrideHeaders
            } else {
                headersToUse = baseHeaders
            }

            guard let request = preset.makeRequest(for: url, method: method, headers: headersToUse, body: overrideBody ?? body) else {
                throw URLError(.badURL)
            }
            return request
        }

        let requestBuilder = self.requestBuilder
        self.loader = {
            let request = try requestBuilder(nil, nil)
            return try await session.data(for: request)
        }
    }

    /// Returns a closure that triggers a request (without overriding the configured body) when called.
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

    /// Requests data asynchronously with a request body.
    ///
    /// If `Request` is `Data`, the bytes are used directly as `httpBody`.
    /// Otherwise, the request model is encoded as JSON and set to `httpBody`.
    /// - Parameter body: The request model or raw bytes used as `httpBody`.
    public func request(with body: Request? = nil) async {
        let encodedBody: Data?
        do {
            encodedBody = try makeHTTPBody(from: body)
        } catch {
            store.setError(.encoding(error))
            return
        }

        let requestBuilder = self.requestBuilder
        let session = self.session
        await Self.performFetch(
            store: store,
            loader: {
                let request = try requestBuilder(encodedBody, nil)
                return try await session.data(for: request)
            },
            decoder: decoder,
            fallbackToRaw: fallbackToRaw,
            errorHandler: errorHandler
        )
    }

    /// Requests data by spawning an async task.
    public func request(with body: Request? = nil) {
        let encodedBody: Data?
        do {
            encodedBody = try makeHTTPBody(from: body)
        } catch {
            store.setError(.encoding(error))
            return
        }

        let requestBuilder = self.requestBuilder
        let session = self.session
        Task {
            await Self.performFetch(
                store: store,
                loader: {
                    let request = try requestBuilder(encodedBody, nil)
                    return try await session.data(for: request)
                },
                decoder: decoder,
                fallbackToRaw: fallbackToRaw,
                errorHandler: errorHandler
            )
        }
    }

    /// Requests data asynchronously using the URL and method configured by the initializer.
    ///
    /// - Parameters:
    ///   - headers: Overrides the configured headers for this request only.
    ///             When non-empty, it replaces all configured headers (including those from presets/configuration/`ResponseModel`).
    ///             When empty, the configured headers are used.
    ///   - body: Optional request body. When `Request == Data`, bytes are used directly as `httpBody`.
    public func request(headers: [String: String] = [:],
                        body: Request? = nil) async {
        let encodedBody: Data?
        do {
            encodedBody = try makeHTTPBody(from: body)
        } catch {
            store.setError(.encoding(error))
            return
        }

        let requestBuilder = self.requestBuilder
        let session = self.session
        await Self.performFetch(
            store: store,
            loader: {
                let request = try requestBuilder(encodedBody, headers)
                return try await session.data(for: request)
            },
            decoder: decoder,
            fallbackToRaw: fallbackToRaw,
            errorHandler: errorHandler
        )
    }

    /// Requests data using the URL and method configured by the initializer by spawning an async task.
    public func request(headers: [String: String] = [:],
                        body: Request? = nil) {
        let encodedBody: Data?
        do {
            encodedBody = try makeHTTPBody(from: body)
        } catch {
            store.setError(.encoding(error))
            return
        }

        let requestBuilder = self.requestBuilder
        let session = self.session
        Task {
            await Self.performFetch(
                store: store,
                loader: {
                    let request = try requestBuilder(encodedBody, headers)
                    return try await session.data(for: request)
                },
                decoder: decoder,
                fallbackToRaw: fallbackToRaw,
                errorHandler: errorHandler
            )
        }
    }


    /// Performs the request, updates state, decodes payload, and optionally stores raw data on decode failure.
    /// - Parameters:
    ///   - store: Mutable request store that receives loading and payload updates.
    ///   - loader: Asynchronous loader that returns response bytes and metadata.
    ///   - decoder: Decoder used to decode `Value` from the response payload.
    ///   - fallbackToRaw: Stores raw response bytes when decode fails if set to `true`.
    ///   - errorHandler: Optional closure invoked on URLSession errors or non-2xx responses.
    private static func performFetch(store: RequestStore<Response>,
                                     loader: @escaping @Sendable () async throws -> (Data, URLResponse),
                                     decoder: JSONDecoder,
                                     fallbackToRaw: Bool,
                                     errorHandler: (@Sendable (Error?, HTTPURLResponse?, Data?) -> Void)?) async {
        store.beginLoading()
        defer { store.finishLoading() }
        #if DEBUG
        // If the response model confirms to Mockable and it's on debug environment, return a mock data.
        if let mockType = Response.self as? Mockable.Type {
            guard let mockModel = mockType.mockData as? Response else {
                store.setResponseCode(500)
                let requestError = RequestError.mockDataError("Cannot cast mock data to \(Response.self). Actual: \(type(of: mockType.mockData))")
                store.setError(requestError)
                return
            }
            store.setMockData(mockModel)
            store.setResponseCode(200)
            store.setError(nil)
            logger.info("Using mock data of \(type(of: Response.self))")
            return
        }
        #endif
        do {
            let (data, response) = try await loader()
            let httpResponse = response as? HTTPURLResponse
            let isSuccessStatus = httpResponse.map { (200...299).contains($0.statusCode) } ?? true
            store.setResponseCode(httpResponse?.statusCode)
            if let httpResponse, !isSuccessStatus {
                let requestError = RequestError.httpStatus(code: httpResponse.statusCode, data: data)
                errorHandler?(requestError, httpResponse, data)
                store.setError(requestError)
            }
            do {
                let decoded = try decoder.decode(Response.self, from: data)
                store.setDecoded(decoded)
                if isSuccessStatus {
                    store.setError(nil)
                }
            } catch {
                let requestError = RequestError.decoding(error)
                if fallbackToRaw {
                    store.setRaw(data)
                    store.setError(requestError)
                } else {
                    store.setError(requestError)
                }
            }
        } catch {
            let requestError = RequestError.network(error)
            errorHandler?(requestError, nil, nil)
            store.setError(requestError)
        }
    }
}

public extension Requestable {
    /// Creates a request wrapper from a payload type plus a response model type and a preset.
    /// - Parameters:
    ///   - payload: The request body model type.
    ///   - response: The response model type that provides static request metadata.
    ///   - preset: Shared request preset containing reusable configuration.
    ///   - session: URL session used to execute the request.
    ///   - encoder: JSON encoder used for request body encoding in `request(with:)`.
    ///   - decoder: JSON decoder used for typed decoding.
    ///   - fallbackToRaw: Stores raw data when decoding fails if set to `true`.
    ///   - errorHandler: Optional closure invoked on URLSession errors or non-2xx responses.
    init(payload: Request.Type,
         response type: Response.Type,
         preset: RequestPreset,
         session: URLSession = .shared,
         encoder: JSONEncoder = JSONEncoder(),
         decoder: JSONDecoder = JSONDecoder(),
         fallbackToRaw: Bool = true,
         errorHandler: (@Sendable (Error?, HTTPURLResponse?, Data?) -> Void)? = nil) where Response: ResponseModel {
        self.init(payload: payload, response: type, configuration: preset.configuration, session: session, encoder: encoder, decoder: decoder, fallbackToRaw: fallbackToRaw, errorHandler: errorHandler)
    }
}


