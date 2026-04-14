//
//  RequestPayload.swift
//  SwiftUIRequest
//
//  Created by Phineas Guo on 2026/4/12.
//

import Foundation

/// Represents either a decoded value or raw response bytes.
public enum RequestPayload<Value: ResponseBaseModel> {
    /// Successfully decoded typed value.
    case decoded(Value)
    /// Raw response data when decoding fails and fallback is enabled.
    case raw(Data)
}
