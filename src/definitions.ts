import { PluginListenerHandle } from "@capacitor/core";
export interface SmartWinnrDailyPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
  joinCall(options: {
    url: string;
    token: string;
    userName?: string;
    coachingTitle?: string;
    maximumTime?: number;
    coachName?: string;
    testMode?: boolean;
    enableScreenShare?: boolean;
    audio_mode_only?: boolean;
    userProfileImageURL?: string;
    coachProfileImageURL?: string;
  }): Promise<{ isCallJoined: boolean }>;
  endCall(): Promise<{ isCallEnded: boolean }>;

  addListener(
    eventName: 'onJoined',
    listenerFunc: () => void,
  ): Promise<PluginListenerHandle>;
  /**
   * Called when the screen recording is stopped.
   *
   * Only available on iOS for now.
   *
   * @since 3.0.2
   */
  addListener(
    eventName: 'onLeft',
    listenerFunc: () => void,
  ): Promise<PluginListenerHandle>;
}
