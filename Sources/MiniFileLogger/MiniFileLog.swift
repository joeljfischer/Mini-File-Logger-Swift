//
//  File.swift
//  MiniFileLogger
//
//  Created by Joel Fischer on 11/30/24.
//

import Foundation

public struct MiniFileLog: ExpressibleByStringLiteral, ExpressibleByStringInterpolation, CustomStringConvertible {
    var message: String

    public init(stringLiteral value: String) {
        self.message = value
    }

    public init(stringInterpolation: MiniFileLogInterpolation) {
        self.message = stringInterpolation.result
    }

    public var description: String { message }

    public typealias StringInterpolation = MiniFileLogInterpolation
    public typealias StringLiteralType = String
    public typealias UnicodeScalarLiteralType = String
}

public struct MiniFileLogInterpolation: StringInterpolationProtocol {
    public typealias StringLiteralType = String

    var result: String

    public init(literalCapacity: Int, interpolationCount: Int) {
        result = ""
    }

    public mutating func appendLiteral(_ literal: String) {
        result.append(literal)
    }

    public mutating func appendInterpolation(_ value: CustomStringConvertible, privacy: MiniFileLogPrivacy = .public) {
        switch privacy {
        case .auto: isDebug ? result.append(value.description) : result.append("[REDACTED]")
        case .private: result.append("[REDACTED]")
        case .public: result.append(value.description)
        }
    }

    public mutating func appendInterpolation(_ value: any Error, privacy: MiniFileLogPrivacy = .public) {
            switch privacy {
            case .auto: isDebug ? result.append(value.localizedDescription) : result.append("[REDACTED]")
            case .private: result.append("[REDACTED]")
            case .public: result.append(value.localizedDescription)
            }
        }

    private var isDebug: Bool {
#if DEBUG
        return true
#else
        return false
#endif
    }
}

public enum MiniFileLogPrivacy {
    /// Always redact the given data
    case `private`

    /// Always show the given data. Default value.
    case `public`

    /// Private in release builds, public in debug builds
    case auto
}
