import Foundation

public enum JSONValue: Codable, Hashable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    public init(from decoder: Decoder) throws {
        if var arrayContainer = try? decoder.unkeyedContainer() {
            var values: [JSONValue] = []
            while !arrayContainer.isAtEnd {
                values.append(try arrayContainer.decode(JSONValue.self))
            }
            self = .array(values)
            return
        }

        if let objectContainer = try? decoder.container(keyedBy: JSONCodingKey.self) {
            var values: [String: JSONValue] = [:]
            for key in objectContainer.allKeys {
                values[key.stringValue] = try objectContainer.decode(JSONValue.self, forKey: key)
            }
            self = .object(values)
            return
        }

        let singleValueContainer = try decoder.singleValueContainer()
        if singleValueContainer.decodeNil() {
            self = .null
        } else if let value = try? singleValueContainer.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? singleValueContainer.decode(Double.self) {
            self = .number(value)
        } else if let value = try? singleValueContainer.decode(String.self) {
            self = .string(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: singleValueContainer,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .object(let values):
            var container = encoder.container(keyedBy: JSONCodingKey.self)
            for (key, value) in values {
                try container.encode(value, forKey: JSONCodingKey(stringValue: key)!)
            }
        case .array(let values):
            var container = encoder.unkeyedContainer()
            for value in values {
                try container.encode(value)
            }
        case .string(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .number(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .bool(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}

private struct JSONCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}
