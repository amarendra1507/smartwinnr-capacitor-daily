//
//  EventModels.swift
//  SmartwinnrCapacitorDaily
//
//  Extracted from DailyCallViewController.swift
//

import Foundation

// MARK: - Server Event Delegate Protocol

protocol ServerEventDelegate: AnyObject {
    func didReceiveServerEvent(_ event: ServerEvent)
    func didReceiveAnimationEvent(_ event: AnimationEvent)
    func didReceiveConversationEvent(_ event: ConversationEvent)
    func didReceiveErrorEvent(_ event: ErrorEvent)
}

// MARK: - Server Event

struct ServerEvent: Codable {
    let type: EventType
    let timestamp: TimeInterval
    let participantId: String?
    let data: [String: Any]

    enum CodingKeys: String, CodingKey {
        case type, timestamp, participantId, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(EventType.self, forKey: .type)
        timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        participantId = try container.decodeIfPresent(String.self, forKey: .participantId)

        if container.contains(.data) {
            data = try container.decode([String: AnyCodable].self, forKey: .data).mapValues { $0.value }
        } else {
            data = [:]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(participantId, forKey: .participantId)
        try container.encode(data.mapValues { AnyCodable($0) }, forKey: .data)
    }
}

// MARK: - AnyCodable

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported type")
            throw EncodingError.invalidValue(value, context)
        }
    }
}

// MARK: - Event Type

enum EventType: String, Codable {
    case animation = "animation"
    case conversation = "conversation"
    case participant = "participant"
    case error = "error"
    case custom = "custom"
}

// MARK: - Animation Event

struct AnimationEvent: Codable {
    let participantId: String
    let animationType: AnimationType
    let duration: TimeInterval?
    let intensity: Float?
    let metadata: [String: String]?

    enum AnimationType: String, Codable {
        case startSpeaking = "start_speaking"
        case stopSpeaking = "stop_speaking"
        case startThinking = "start_thinking"
        case stopThinking = "stop_thinking"
        case pulse = "pulse"
        case highlight = "highlight"
        case fadeIn = "fade_in"
        case fadeOut = "fade_out"
        case custom = "custom"
    }
}

// MARK: - Conversation Event

struct ConversationEvent: Codable {
    let participantId: String
    let action: ConversationAction
    let turnNumber: Int?
    let timestamp: TimeInterval
    let message: String?

    enum ConversationAction: String, Codable {
        case turnStart = "turn_start"
        case turnEnd = "turn_end"
        case messageReceived = "message_received"
        case messageSent = "message_sent"
        case aiResponse = "ai_response"
    }
}

// MARK: - Error Event

struct ErrorEvent: Codable {
    let errorCode: String
    let message: String
    let participantId: String?
    let severity: ErrorSeverity

    enum ErrorSeverity: String, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
    }
}
