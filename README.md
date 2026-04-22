# smartwinnr-capacitor-daily

A capacitor plugin for ionic app which allows to use the daily.co call functionality

## Install

```bash
npm install smartwinnr-capacitor-daily
npx cap sync
```

## API

<docgen-index>

* [`echo(...)`](#echo)
* [`joinCall(...)`](#joincall)
* [`endCall()`](#endcall)
* [`addListener('onJoined', ...)`](#addlisteneronjoined-)
* [`addListener('onLeft', ...)`](#addlisteneronleft-)
* [`addListener('pdfPageChanged', ...)`](#addlistenerpdfpagechanged-)
* [`addListener('pdfTrackingUpdate', ...)`](#addlistenerpdftrackingupdate-)
* [`addListener('pdfLoadError', ...)`](#addlistenerpdfloaderror-)
* [`addListener('pagePresentationTracking', ...)`](#addlistenerpagepresentationtracking-)
* [Interfaces](#interfaces)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### echo(...)

```typescript
echo(options: { value: string; }) => Promise<{ value: string; }>
```

| Param         | Type                            |
| ------------- | ------------------------------- |
| **`options`** | <code>{ value: string; }</code> |

**Returns:** <code>Promise&lt;{ value: string; }&gt;</code>

--------------------


### joinCall(...)

```typescript
joinCall(options: { url: string; token: string; userName?: string; coachingTitle?: string; maximumTime?: number; coachName?: string; testMode?: boolean; enableScreenShare?: boolean; audio_mode_only?: boolean; userProfileImageURL?: string; coachProfileImageURL?: string; is_sharable_resources_available?: boolean; sharable_resources?: SharableResource[]; }) => Promise<{ isCallJoined: boolean; }>
```

| Param         | Type                                                                                                                                                                                                                                                                                                                                                           |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`options`** | <code>{ url: string; token: string; userName?: string; coachingTitle?: string; maximumTime?: number; coachName?: string; testMode?: boolean; enableScreenShare?: boolean; audio_mode_only?: boolean; userProfileImageURL?: string; coachProfileImageURL?: string; is_sharable_resources_available?: boolean; sharable_resources?: SharableResource[]; }</code> |

**Returns:** <code>Promise&lt;{ isCallJoined: boolean; }&gt;</code>

--------------------


### endCall()

```typescript
endCall() => Promise<{ isCallEnded: boolean; }>
```

**Returns:** <code>Promise&lt;{ isCallEnded: boolean; }&gt;</code>

--------------------


### addListener('onJoined', ...)

```typescript
addListener(eventName: 'onJoined', listenerFunc: () => void) => Promise<PluginListenerHandle>
```

| Param              | Type                       |
| ------------------ | -------------------------- |
| **`eventName`**    | <code>'onJoined'</code>    |
| **`listenerFunc`** | <code>() =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('onLeft', ...)

```typescript
addListener(eventName: 'onLeft', listenerFunc: () => void) => Promise<PluginListenerHandle>
```

Called when the screen recording is stopped.

Only available on iOS for now.

| Param              | Type                       |
| ------------------ | -------------------------- |
| **`eventName`**    | <code>'onLeft'</code>      |
| **`listenerFunc`** | <code>() =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

**Since:** 3.0.2

--------------------


### addListener('pdfPageChanged', ...)

```typescript
addListener(eventName: 'pdfPageChanged', listenerFunc: (event: PdfPageChangedEvent) => void) => Promise<PluginListenerHandle>
```

Fires when the active PDF page changes. Only emitted when the call was
joined with `is_sharable_resources_available: true`. iOS only.

| Param              | Type                                                                                    |
| ------------------ | --------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'pdfPageChanged'</code>                                                           |
| **`listenerFunc`** | <code>(event: <a href="#pdfpagechangedevent">PdfPageChangedEvent</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

**Since:** 3.1.0

--------------------


### addListener('pdfTrackingUpdate', ...)

```typescript
addListener(eventName: 'pdfTrackingUpdate', listenerFunc: (event: PdfTrackingData) => void) => Promise<PluginListenerHandle>
```

Fires on a fixed interval (default every 2s) with a snapshot of PDF
tracking data, plus a final snapshot when the call ends. Only emitted
when the call was joined with `is_sharable_resources_available: true`. iOS only.

| Param              | Type                                                                            |
| ------------------ | ------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'pdfTrackingUpdate'</code>                                                |
| **`listenerFunc`** | <code>(event: <a href="#pdftrackingdata">PdfTrackingData</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

**Since:** 3.1.0

--------------------


### addListener('pdfLoadError', ...)

```typescript
addListener(eventName: 'pdfLoadError', listenerFunc: (event: PdfLoadErrorEvent) => void) => Promise<PluginListenerHandle>
```

Fires if the PDF fails to load or render. iOS only.

| Param              | Type                                                                                |
| ------------------ | ----------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'pdfLoadError'</code>                                                         |
| **`listenerFunc`** | <code>(event: <a href="#pdfloaderrorevent">PdfLoadErrorEvent</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

**Since:** 3.1.0

--------------------


### addListener('pagePresentationTracking', ...)

```typescript
addListener(eventName: 'pagePresentationTracking', listenerFunc: (event: { entries: PagePresentationEntry[]; }) => void) => Promise<PluginListenerHandle>
```

Emitted each time the active PDF page closes (on page change, document
switch, or call end). The payload is the full cumulative list of page
presentation entries across the session. iOS only.

| Param              | Type                                                                   |
| ------------------ | ---------------------------------------------------------------------- |
| **`eventName`**    | <code>'pagePresentationTracking'</code>                                |
| **`listenerFunc`** | <code>(event: { entries: PagePresentationEntry[]; }) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

**Since:** 3.1.0

--------------------


### Interfaces


#### SharableResource

| Prop               | Type                |
| ------------------ | ------------------- |
| **`id`**           | <code>string</code> |
| **`url`**          | <code>string</code> |
| **`display_name`** | <code>string</code> |


#### PluginListenerHandle

| Prop         | Type                                      |
| ------------ | ----------------------------------------- |
| **`remove`** | <code>() =&gt; Promise&lt;void&gt;</code> |


#### PdfPageChangedEvent

| Prop             | Type                |
| ---------------- | ------------------- |
| **`pageNumber`** | <code>number</code> |
| **`totalPages`** | <code>number</code> |


#### PdfTrackingData

| Prop                     | Type                            |
| ------------------------ | ------------------------------- |
| **`totalTimeSpentMs`**   | <code>number</code>             |
| **`totalPages`**         | <code>number</code>             |
| **`currentPage`**        | <code>number</code>             |
| **`pagesViewed`**        | <code>number</code>             |
| **`progressPercentage`** | <code>number</code>             |
| **`pageTimeEntries`**    | <code>PdfPageTimeEntry[]</code> |
| **`isFinal`**            | <code>boolean</code>            |


#### PdfPageTimeEntry

| Prop              | Type                 |
| ----------------- | -------------------- |
| **`pageNumber`**  | <code>number</code>  |
| **`timeSpentMs`** | <code>number</code>  |
| **`dwellMs`**     | <code>number</code>  |
| **`viewed`**      | <code>boolean</code> |


#### PdfLoadErrorEvent

| Prop        | Type                |
| ----------- | ------------------- |
| **`error`** | <code>string</code> |
| **`url`**   | <code>string</code> |


#### PagePresentationEntry

| Prop              | Type                |
| ----------------- | ------------------- |
| **`documentId`**  | <code>string</code> |
| **`pageNumber`**  | <code>number</code> |
| **`startTime`**   | <code>number</code> |
| **`endTime`**     | <code>number</code> |
| **`timeSpentMs`** | <code>number</code> |

</docgen-api>
