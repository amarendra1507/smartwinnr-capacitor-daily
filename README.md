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

</docgen-api>
