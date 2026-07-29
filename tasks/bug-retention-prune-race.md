# BUG — Retention prune deletes captures before the subscription status is known

> **FIXED 2026-07-28.** All three parts of the fix below are implemented, plus the Trash and
> error-logging items from "Also worth fixing". Covered by `Tests/WatchdogTests/RetentionPolicyTests.swift`
> (6 tests), which were confirmed to fail against the old behaviour before being committed —
> reintroducing the missing `hasResolvedStatus` guard fails 2 of them by name.
>
> Still outstanding: the **pre-deletion warning** (audit item R7). A lapsing subscriber is still
> pruned without notice or a chance to export first. That is a product decision, not a race.

**Severity: critical.** Silent, permanent user-data loss. Affects trial and paying Pro users,
not just the free tier. Fires on every launch.

Observed 2026-07-27: a real capture folder (~40 stills from 2026-07-23) was emptied — 0 files
left, `captures.json` rewritten to `[]`. Nothing in the Trash; the media is unrecoverable.

---

## The chain

| Step | Location | State |
|---|---|---|
| 1 | `SubscriptionManager.swift:21` | `@Published var status: SubscriptionStatus = .free` — the **default** |
| 2 | `SubscriptionManager.swift:37-41` | the real status is resolved **asynchronously** inside `Task { … }` (`loadProducts()` hits the network) |
| 3 | `SubscriptionManager.swift:129-131` | `isProUser` → `status.isProUser` → **`false`** while still `.free` |
| 4 | `SettingsManager.swift:80-82` | `isPaid` → `SubscriptionManager.shared.isProUser` → **`false`** |
| 5 | `SettingsManager.swift:148-150` | `historyDayLimit` → `isPaid ? nil : 3` → **`3`** |
| 6 | `WatchdogApp.swift:60` | `captureStore.pruneExpiredCaptures()` runs **synchronously** in `applicationDidFinishLaunching` |
| 7 | `CaptureStore.swift:89-91` | every record older than 3 days → `removeMedia(for:)` |
| 8 | `CaptureStore.swift:101-105` | `FileManager.default.removeItem(...)` — **unlink, not Trash** |

`SubscriptionManager.shared` is created as an `AppDelegate` stored property, so its `init` runs
*before* `applicationDidFinishLaunching`. Its `Task` cannot have completed by step 6 — it awaits
`Product.products(for:)`. So at the moment the prune runs, `status` is reliably `.free`.

## Impact by plan

| User | Expected retention | What actually happens at launch |
|---|---|---|
| Free | 3 days | 3 days — correct (but see "no warning" below) |
| **Trial** | unlimited | **everything >3 days old is deleted** |
| **Pro subscriber** | unlimited | **everything >3 days old is deleted** |

A subscriber who opens the app after a week away loses their history. There is no confirmation,
no warning, no undo, and the files do not go to the Trash.

## Reproduce

1. Have captures older than 3 days in the capture folder.
2. Be on trial or subscribed (`status` will resolve to `.trial` / `.subscribed`, just not yet).
3. Launch the app.
4. The gallery is empty; the `.jpg`/`.mov` files are gone from disk.

The `os_log` line at `CaptureStore.swift:98` records the deletion, so Console will show
`Pruned N capture(s) past the 3-day retention window` even for a Pro user.

## Fix

The rule: **never delete on an unknown state — fail open.**

### 1. Track whether the status has actually resolved

```swift
// SubscriptionManager
@Published private(set) var hasResolvedStatus = false

// at the end of updateSubscriptionStatus():
hasResolvedStatus = true
```

### 2. Make the retention limit unknowable rather than restrictive

```swift
// SettingsManager
var historyDayLimit: Int? {
    // Until StoreKit has answered, we do not know whether this user is entitled to
    // unlimited history — so we must not enforce a limit. Deleting on an assumed-free
    // state destroys paying users' captures irreversibly.
    guard SubscriptionManager.shared.hasResolvedStatus else { return nil }
    return isPaid ? nil : 3
}
```

`pruneExpiredCaptures()` already `guard let dayLimit = …historyDayLimit else { return }`, so this
alone makes the launch-time call a no-op until the status is known.

### 3. Prune once the status is known, instead of at launch

Drop the call at `WatchdogApp.swift:60` and drive it from the resolution instead:

```swift
SubscriptionManager.shared.$hasResolvedStatus
    .filter { $0 }
    .first()
    .sink { [weak self] _ in self?.captureStore.pruneExpiredCaptures() }
    .store(in: &cancellables)
```

The existing hourly timer (`CaptureStore.swift:31`) then continues to cover long-running sessions,
by which point the status is always resolved.

## Also worth fixing while in here

- **No warning before destructive retention.** The compliance audit's own item R7 asked for this:
  *"when a Pro subscription lapses, >3-day-old captures vanish… warn the user before that happens."*
  The warning was never added, and the behaviour has since gone from *hiding* records to *deleting*
  files. A lapsing subscriber should get a notice and a chance to export first.
- **Deletion bypasses the Trash.** `removeItem` unlinks. For photographs of people, moving to the
  Trash (`FileManager.trashItem(at:resultingItemURL:)`) makes an accidental purge recoverable and
  costs nothing.
- **`try?` swallows failures.** `CaptureStore.swift:103-105` discards the error, so a partial
  delete (record dropped, file left on disk) is silent — the exact orphaning R7 set out to fix.

## Notes

- Not caused by the marketing/screenshot work; that only triggered it by relaunching the app.
  The bug is reachable by any user on any launch.
- `pruneExpiredCaptures(persist:)` itself is correct in isolation. The defect is the *input*:
  it trusts `historyDayLimit` at a moment when that value is a placeholder, not an answer.
