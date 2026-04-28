//
//  File.swift
//  SwiftUIRequest
//
//  Created by Phineas Guo on 2026/4/17.
//

import Foundation

public enum RequestError: LocalizedError, Sendable {
    case mockDataError(String)
    case httpStatus(code: Int, data: Data?)
    case encoding(Error)
    case network(Error)
    case decoding(Error)

    public var errorDescription: String {
        switch self {
        case .mockDataError(let message):
            return message
        case .httpStatus(let code, _):
            return "HTTP request failed with status code \(code)."
        case .encoding(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        case .decoding(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}
