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
joinCall(options: { url: string; token: string; }) => Promise<{ isCallJoined: boolean; }>
```

| Param         | Type                                         |
| ------------- | -------------------------------------------- |
| **`options`** | <code>{ url: string; token: string; }</code> |

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


### Interfaces


#### PluginListenerHandle

| Prop         | Type                                      |
| ------------ | ----------------------------------------- |
| **`remove`** | <code>() =&gt; Promise&lt;void&gt;</code> |

</docgen-api>
