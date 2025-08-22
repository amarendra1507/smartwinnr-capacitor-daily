# Server Event Delegate System

This document explains how to use the server event delegate system to listen for events from the server and trigger animations in the Daily.co video call interface.

## Overview

The system provides a comprehensive delegate pattern for handling JSON-based events from the server that can trigger various animations and UI updates in real-time during video calls.

## Key Components

### 1. ServerEventDelegate Protocol

```swift
protocol ServerEventDelegate: AnyObject {
    func didReceiveServerEvent(_ event: ServerEvent)
    func didReceiveAnimationEvent(_ event: AnimationEvent)
    func didReceiveConversationEvent(_ event: ConversationEvent)
    func didReceiveErrorEvent(_ event: ErrorEvent)
}
```

### 2. Event Models

#### ServerEvent
The main event structure that wraps all types of events:
```swift
struct ServerEvent: Codable {
    let type: EventType // .animation, .conversation, .participant, .error, .custom
    let timestamp: TimeInterval
    let participantId: String?
    let data: [String: Any]
}
```

#### AnimationEvent
Specific events for triggering animations:
```swift
struct AnimationEvent: Codable {
    let participantId: String
    let animationType: AnimationType
    let duration: TimeInterval?
    let intensity: Float?
    let metadata: [String: String]?
}
```

#### ConversationEvent
Events related to conversation flow:
```swift
struct ConversationEvent: Codable {
    let participantId: String
    let action: ConversationAction
    let turnNumber: Int?
    let timestamp: TimeInterval
    let message: String?
}
```

## Usage

### Setting Up the Delegate

```swift
// Implement the delegate in your class
class YourViewController: UIViewController, ServerEventDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set yourself as the delegate
        dailyCallViewController.serverEventDelegate = self
    }
    
    // Implement delegate methods
    func didReceiveServerEvent(_ event: ServerEvent) {
        print("Received server event: \(event.type)")
    }
    
    func didReceiveAnimationEvent(_ event: AnimationEvent) {
        print("Animation event: \(event.animationType)")
        // Custom animation handling
    }
    
    func didReceiveConversationEvent(_ event: ConversationEvent) {
        print("Conversation event: \(event.action)")
        // Handle conversation flow
    }
    
    func didReceiveErrorEvent(_ event: ErrorEvent) {
        print("Error event: \(event.errorCode) - \(event.message)")
        // Handle errors
    }
}
```

### Processing JSON Events from Server

The system automatically listens for Daily.co app messages that contain JSON events:

```swift
// The system automatically processes incoming app messages
// You can also manually process JSON strings:
let jsonString = """
{
  "type": "animation",
  "timestamp": 1640995200.0,
  "participantId": "remote_participant_123",
  "data": {
    "participantId": "remote_participant_123",
    "animationType": "start_speaking",
    "duration": 2.0,
    "intensity": 0.8
  }
}
"""

dailyCallViewController.processServerEventFromJSON(jsonString)
```

### Sending Events

You can also send events to other participants:

```swift
let event = ServerEvent(
    type: .animation,
    timestamp: Date().timeIntervalSince1970,
    participantId: "remote_participant_123",
    data: [
        "participantId": "remote_participant_123",
        "animationType": "start_thinking",
        "duration": 3.0
    ]
)

dailyCallViewController.sendServerEventAsAppMessage(event)
```

## Supported Animation Types

### Speaking Animations
- `start_speaking`: Highlights participant video with green border and pulse effect
- `stop_speaking`: Removes speaking highlight
- `start_thinking`: Shows animated dots overlay for AI participants
- `stop_thinking`: Removes thinking animation

### Visual Effects
- `pulse`: Scales the video view with customizable intensity
- `highlight`: Temporarily highlights video border in yellow
- `fadeIn`: Fades video from transparent to opaque
- `fadeOut`: Fades video to semi-transparent

### Custom Animations
- `bounce`: Bouncing scale animation
- `shake`: Horizontal shake animation  
- `glow`: Glowing shadow effect
- `custom`: User-defined animations via metadata

## JSON Event Examples

### 1. Speaking Animation
```json
{
  "type": "animation",
  "timestamp": 1640995200.0,
  "participantId": "remote_participant_123",
  "data": {
    "participantId": "remote_participant_123",
    "animationType": "start_speaking",
    "duration": 2.0,
    "intensity": 0.8,
    "metadata": {
      "reason": "ai_response"
    }
  }
}
```

### 2. Thinking Animation
```json
{
  "type": "animation",
  "timestamp": 1640995200.0,
  "participantId": "remote_participant_123",
  "data": {
    "participantId": "remote_participant_123",
    "animationType": "start_thinking",
    "duration": 3.0
  }
}
```

### 3. Custom Animation
```json
{
  "type": "animation",
  "timestamp": 1640995200.0,
  "participantId": "remote_participant_123", 
  "data": {
    "participantId": "remote_participant_123",
    "animationType": "custom",
    "metadata": {
      "type": "bounce",
      "intensity": "high"
    }
  }
}
```

### 4. Conversation Event
```json
{
  "type": "conversation",
  "timestamp": 1640995200.0,
  "participantId": "remote_participant_123",
  "data": {
    "participantId": "remote_participant_123",
    "action": "turn_start",
    "turnNumber": 5,
    "timestamp": 1640995200.0,
    "message": "AI is starting to respond"
  }
}
```

### 5. Participant State Event
```json
{
  "type": "participant",
  "timestamp": 1640995200.0,
  "participantId": "remote_participant_123",
  "data": {
    "is_speaking": true,
    "is_thinking": false,
    "is_local": false
  }
}
```

## Testing

### Simulate Events for Testing
```swift
// Test animation event
dailyCallViewController.testAnimationEvent(
    participantId: "test_participant",
    animationType: .pulse,
    duration: 1.5,
    intensity: 0.8
)

// Simulate server event
dailyCallViewController.simulateServerEvent(
    type: .animation,
    participantId: "test_participant",
    data: [
        "participantId": "test_participant",
        "animationType": "bounce"
    ]
)
```

### Enable/Disable Event Handling
```swift
// Enable event processing
dailyCallViewController.setEventHandlingActive(true)

// Disable event processing
dailyCallViewController.setEventHandlingActive(false)
```

## Integration with Web/JavaScript

From your web application, you can send events using Daily.co's app message system:

```javascript
// Send animation event from web to iOS
callFrame.sendAppMessage({
  type: "server_event",
  data: JSON.stringify({
    type: "animation",
    timestamp: Date.now() / 1000,
    participantId: "remote_participant_123",
    data: {
      participantId: "remote_participant_123",
      animationType: "start_thinking",
      duration: 3.0
    }
  })
});
```

## Error Handling

The system includes comprehensive error handling:
- JSON parsing errors are automatically caught and reported
- Invalid event formats trigger error events
- Network issues are handled gracefully
- Critical errors can optionally trigger call termination

## Thread Safety

- All JSON parsing is done on a background queue
- UI updates are automatically dispatched to the main queue
- Event handling can be safely enabled/disabled from any thread

## Best Practices

1. **Always validate participant IDs** before sending events
2. **Use appropriate animation durations** (0.5-3.0 seconds recommended)
3. **Handle delegate methods efficiently** to avoid blocking the main thread
4. **Test with various event formats** to ensure robust parsing
5. **Monitor performance** when processing many events rapidly
6. **Implement fallback UI states** for critical animation failures

This system provides a flexible, extensible foundation for real-time event-driven animations in your Daily.co video calling application.
