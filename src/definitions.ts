import type { PluginListenerHandle } from '@capacitor/core';

export interface PdfPageTimeEntry {
  pageNumber: number;
  timeSpentMs: number;
  dwellMs: number;
  viewed: boolean;
}

export interface PdfTrackingData {
  totalTimeSpentMs: number;
  totalPages: number;
  currentPage: number;
  pagesViewed: number;
  progressPercentage: number;
  pageTimeEntries: PdfPageTimeEntry[];
  isFinal?: boolean;
}

export interface PdfPageChangedEvent {
  pageNumber: number;
  totalPages: number;
}

export interface PdfLoadErrorEvent {
  error: string;
  url?: string;
}

export interface PagePresentationEntry {
  documentId: string;
  pageNumber: number;
  startTime: number;
  endTime: number;
  timeSpentMs: number;
}

export interface SharableResource {
  id: string;
  url: string;
  display_name?: string;
  /**
   * Resource kind. Defaults to 'pdf' when omitted (backwards compatible). A
   * 'video' resource is rendered natively (AVPlayer on `hls_resource_url`).
   *
   * @since 3.3.0
   */
  resource_type?: 'pdf' | 'video';
  /**
   * For a video resource: the HLS playlist url the native player streams.
   *
   * @since 3.3.0
   */
  hls_resource_url?: string;
  /**
   * For a video resource: a poster/thumbnail image url.
   *
   * @since 3.3.0
   */
  poster_url?: string;
  /**
   * For a video resource: the Bunny.net video id (metadata).
   *
   * @since 3.3.0
   */
  video_id?: string;
}

export interface VideoStateChangedEvent {
  /** Whether the video is currently playing. */
  isPlaying: boolean;
  /** Current playback position in milliseconds. */
  currentTimeMs: number;
  /** Total video duration in milliseconds (0 until known). */
  durationMs: number;
  /** True when the emit was triggered by playback reaching the end. */
  ended?: boolean;
}

export interface VideoLoadErrorEvent {
  error: string;
  url?: string;
}

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
    /**
     * When true, a native pre-call screen is shown before joining where the
     * user can preview their camera, pick the audio route (speaker/bluetooth/
     * wired/earpiece), flip the camera, and confirm the microphone is
     * capturing (live level meter) before the call connects. iOS only.
     *
     * @since 3.2.0
     */
    show_precall?: boolean;
    userProfileImageURL?: string;
    coachProfileImageURL?: string;
    /**
     * When true, a PDF document from `sharable_resources` will be rendered at
     * the center of the call screen with the user and AI tiles shown as
     * draggable floating PiP overlays. iOS only.
     *
     * @since 3.1.0
     */
    is_sharable_resources_available?: boolean;
    /**
     * List of sharable resources. The first entry is used as the active
     * document when `is_sharable_resources_available` is true.
     *
     * @since 3.1.0
     */
    sharable_resources?: SharableResource[];
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
  /**
   * Fires when the active PDF page changes. Only emitted when the call was
   * joined with `is_sharable_resources_available: true`. iOS only.
   *
   * @since 3.1.0
   */
  addListener(
    eventName: 'pdfPageChanged',
    listenerFunc: (event: PdfPageChangedEvent) => void,
  ): Promise<PluginListenerHandle>;
  /**
   * Fires on a fixed interval (default every 2s) with a snapshot of PDF
   * tracking data, plus a final snapshot when the call ends. Only emitted
   * when the call was joined with `is_sharable_resources_available: true`. iOS only.
   *
   * @since 3.1.0
   */
  addListener(
    eventName: 'pdfTrackingUpdate',
    listenerFunc: (event: PdfTrackingData) => void,
  ): Promise<PluginListenerHandle>;
  /**
   * Fires if the PDF fails to load or render. iOS only.
   *
   * @since 3.1.0
   */
  addListener(
    eventName: 'pdfLoadError',
    listenerFunc: (event: PdfLoadErrorEvent) => void,
  ): Promise<PluginListenerHandle>;
  /**
   * Emitted each time the active PDF page closes (on page change, document
   * switch, or call end). The payload is the full cumulative list of page
   * presentation entries across the session. iOS only.
   *
   * @since 3.1.0
   */
  addListener(
    eventName: 'pagePresentationTracking',
    listenerFunc: (event: { entries: PagePresentationEntry[] }) => void,
  ): Promise<PluginListenerHandle>;
  /**
   * Fires when a video sharable resource's playback state changes (play/pause,
   * periodic progress, and on end). Only emitted for `resource_type: 'video'`
   * resources when the call was joined with `is_sharable_resources_available: true`.
   * iOS only.
   *
   * @since 3.3.0
   */
  addListener(
    eventName: 'videoStateChanged',
    listenerFunc: (event: VideoStateChangedEvent) => void,
  ): Promise<PluginListenerHandle>;
  /**
   * Fires if a video sharable resource fails to load or play. iOS only.
   *
   * @since 3.3.0
   */
  addListener(
    eventName: 'videoLoadError',
    listenerFunc: (event: VideoLoadErrorEvent) => void,
  ): Promise<PluginListenerHandle>;
}
