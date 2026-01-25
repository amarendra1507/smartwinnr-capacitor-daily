# Picture-in-Picture (PiP) Mode for Screen Sharing

## Overview

This document describes the Picture-in-Picture implementation for the SmartWinnr Daily Capacitor plugin on iOS. When screen sharing is activated, the app automatically enters PiP mode, allowing users to see their shared screen content while maintaining access to the video call in a small floating window.

## Features

- **Automatic PiP Activation**: When screen sharing starts, the app automatically enters PiP mode
- **Automatic PiP Deactivation**: When screen sharing stops, the app returns to normal full-screen mode
- **Seamless Transition**: Smooth transitions between normal and PiP modes
- **iOS Native Integration**: Uses AVKit's AVPictureInPictureController for native iOS PiP experience

## Requirements

- **iOS Version**: iOS 15.0 or later
- **Device**: PiP is supported on iPad and iPhone (check device capabilities)
- **Permissions**: Background modes capability (if needed for extended PiP support)

## Implementation Details

### Key Components

1. **AVPictureInPictureController**: Manages the PiP window
2. **AVPlayerLayer**: Required by PiP controller (uses a placeholder video)
3. **AVPlayer**: Plays minimal video content to enable PiP
4. **Screen Sharing Detection**: Integrated with Daily SDK's broadcast callbacks

### How It Works

1. **Setup Phase** (`setupPictureInPicture()`)
   - Configures audio session for video chat
   - Creates an AVPlayer with a placeholder video layer
   - Initializes AVPictureInPictureController
   - Sets up delegate methods

2. **Start Screen Sharing** (`callClientDidDetectStartOfSystemBroadcast`)
   - Daily SDK detects screen sharing start
   - Enables screen video input
   - Triggers `startPictureInPicture()` method
   - App enters PiP mode

3. **Stop Screen Sharing** (`callClientDidDetectEndOfSystemBroadcast`)
   - Daily SDK detects screen sharing end
   - Disables screen video input
   - Triggers `stopPictureInPicture()` method
   - App returns to normal mode

4. **Cleanup** (`deinit`)
   - Stops PiP if active
   - Releases player and layer resources
   - Removes notification observers

### Code Structure

```swift
// Properties
private var pipController: AVPictureInPictureController?
private var pipPlayerLayer: AVPlayerLayer?
private var pipPlayer: AVPlayer?
private var isScreenSharingActive: Bool = false

// Main Methods
setupPictureInPicture()      // Initialize PiP controller
startPictureInPicture()       // Enter PiP mode
stopPictureInPicture()        // Exit PiP mode
createMinimalVideoAsset()     // Generate placeholder video
```

## Delegate Methods

The implementation conforms to `AVPictureInPictureControllerDelegate`:

- `pictureInPictureControllerWillStartPictureInPicture`: Called before PiP starts
- `pictureInPictureControllerDidStartPictureInPicture`: Called after PiP starts
- `pictureInPictureControllerWillStopPictureInPicture`: Called before PiP stops
- `pictureInPictureControllerDidStopPictureInPicture`: Called after PiP stops
- `restoreUserInterfaceForPictureInPictureStop`: Called when user taps restore button

## Placeholder Video

Since Daily SDK manages the actual video streams, the PiP controller uses a minimal placeholder video:

- Small resolution (320x180)
- Single frame (dark gray)
- Loops continuously
- Stored in temporary directory
- Generated on first use

This approach allows PiP to function while the actual video content is handled by Daily SDK's VideoView components.

## Configuration

### Info.plist Requirements

Add the following to your app's `Info.plist` if not already present:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

### Audio Session

The implementation configures the audio session with:
- Category: `.playback`
- Mode: `.videoChat`
- Options: `.mixWithOthers`, `.allowBluetooth`

## Usage

The PiP feature is automatic and requires no additional code in your app. Simply:

1. Start a Daily call
2. Initiate screen sharing (iOS ReplayKit broadcast)
3. PiP mode activates automatically
4. Stop screen sharing
5. App returns to normal mode automatically

## Troubleshooting

### PiP Not Starting

**Issue**: PiP mode doesn't activate when screen sharing starts

**Possible Causes**:
- iOS version < 15.0
- Device doesn't support PiP
- Player not in valid state

**Solution**:
- Check iOS version compatibility
- Verify device capabilities
- Check console logs for error messages

### PiP Window Shows Black Screen

**Issue**: PiP window displays black content

**Expected**: This is normal behavior. The placeholder video is intentionally minimal (dark gray). The actual video content from the Daily call is managed separately by the Daily SDK.

### PiP Doesn't Stop When Screen Sharing Ends

**Issue**: App remains in PiP mode after screen sharing stops

**Solution**:
- Check that `callClientDidDetectEndOfSystemBroadcast` is being called
- Verify pipController is not nil
- Check for errors in console logs

## Limitations

1. **Placeholder Video**: PiP uses a minimal placeholder rather than actual call video
2. **iOS 15+**: Requires iOS 15.0 or later
3. **Device Support**: Not all iOS devices support PiP
4. **Background Limitations**: PiP behavior may be limited in background mode

## Future Enhancements

Possible improvements for future versions:

1. **Real Video Content**: Integrate Daily SDK video tracks directly into PiP window
2. **Custom Controls**: Add custom controls to PiP window
3. **Multiple Participants**: Show multiple participant videos in PiP
4. **Configurable Behavior**: Allow users to opt-out of automatic PiP

## Testing

To test the PiP feature:

1. Build and run the app on a physical iOS device (iOS 15+)
2. Join a Daily call
3. Start screen sharing using Control Center > Screen Recording
4. Select your app as the broadcast target
5. Observe app entering PiP mode
6. Stop screen sharing
7. Observe app returning to normal mode

## Notes

- PiP is only available on physical devices, not in the iOS Simulator
- Screen sharing requires ReplayKit framework
- Users must grant permission for screen recording
- PiP window size and position are controlled by iOS

## Support

For issues or questions related to PiP implementation, check:
- iOS Console logs for error messages
- AVFoundation and AVKit documentation
- Daily SDK documentation for screen sharing
