import Foundation

/// A loosely-typed JSON value. The API's schema is versioned, so rows are decoded
/// into this first and mapped to app models through `Record`, which tolerates
/// renamed or missing fields instead of failing the whole response.
enum JSONValue: Decodable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }
}

/// One row from an OData entity set, with case-insensitive, multi-candidate lookup.
struct Record: Sendable {
    private let fields: [String: JSONValue]

    init(_ raw: [String: JSONValue]) {
        var lowered: [String: JSONValue] = [:]
        for (key, value) in raw { lowered[key.lowercased()] = value }
        fields = lowered
    }

    private func first(_ keys: [String]) -> JSONValue? {
        for key in keys {
            if let value = lookup(key), value != .null { return value }
        }
        return nil
    }

    /// Resolves `name` or a dotted path such as `geography.name` into expanded records.
    private func lookup(_ path: String) -> JSONValue? {
        let parts = path.lowercased().split(separator: ".").map(String.init)
        guard let head = parts.first, var current = fields[head] else { return nil }
        for part in parts.dropFirst() {
            guard case .object(let object) = current,
                  let next = object.first(where: { $0.key.lowercased() == part })?.value
            else { return nil }
            current = next
        }
        return current
    }

    func string(_ keys: [String]) -> String? {
        switch first(keys) {
        case .string(let s):
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case .number(let n):
            return n == n.rounded() ? String(Int64(n)) : String(n)
        case .bool(let b):
            return String(b)
        default:
            return nil
        }
    }

    func double(_ keys: [String]) -> Double? {
        switch first(keys) {
        case .number(let n): return n
        case .string(let s): return Double(s)
        default: return nil
        }
    }

    func date(_ keys: [String]) -> Date? {
        guard let raw = string(keys) else { return nil }
        return ODataDate.parse(raw)
    }

    func int(_ keys: [String]) -> Int? {
        double(keys).map { Int($0) }
    }

    /// Rows of an expanded collection, e.g. a funding request's `implementationPeriods`.
    func records(_ keys: [String]) -> [Record] {
        guard case .array(let items) = first(keys) else { return [] }
        var result: [Record] = []
        for item in items {
            if case .object(let object) = item { result.append(Record(object)) }
        }
        return result
    }
}

enum ODataDate {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let dayOnly: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let noZone: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f
    }()

    static func parse(_ raw: String) -> Date? {
        withFraction.date(from: raw)
            ?? plain.date(from: raw)
            ?? noZone.date(from: String(raw.prefix(19)))
            ?? dayOnly.date(from: String(raw.prefix(10)))
    }
}
