# Watchdog - Lessons Learned

## SwiftUI Singleton Observation
- **Pattern**: `SomeManager.shared.someProperty` read directly in a SwiftUI view body
- **Problem**: SwiftUI only re-evaluates `body` when it observes changes via `@EnvironmentObject`, `@ObservedObject`, or `@StateObject`. Direct singleton reads are evaluated once and never trigger re-renders.
- **Fix**: Always pass ObservableObject singletons through `@EnvironmentObject` and inject them via `.environmentObject()` at the root.
- **Check**: After adding any ObservableObject dependency to a view, grep for `TypeName.shared` in all UI files to catch stale direct reads.

## Dead Code from Incomplete Implementation
- **Pattern**: Timer/observer set up to call a method, but the method body is empty or only has comments
- **Lesson**: During audits, check that all scheduled callbacks actually do meaningful work. An empty callback is wasted CPU and a maintenance trap.

## File Reference Validation
- **Pattern**: Model stores a file path string, but the file can be deleted independently
- **Lesson**: When loading persisted records that reference files, validate those files still exist. Nil out stale references rather than discarding the entire record.

## VideoRecorder Completion Safety
- **Pattern**: Storing a closure as `self.completion` and calling it in one path, then running `cleanup()` which also nils it
- **Problem**: If cleanup doesn't check whether completion was already fired, it can double-fire or silently drop callbacks
- **Fix**: Nil out `self.completion` immediately after calling it, so cleanup sees nil and only fires as a safety net for the edge case where the normal path didn't fire.
