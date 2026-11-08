# RemindMe · Flutter

The Flutter app for RemindMe Companion. See the [repository guide](../README.md) for setup, preview commands, Android permissions, and limitations.

- `lib/main.dart`: task interface, companion settings, and browser pet preview.
- `lib/companion_model.dart`: task and preference persistence, filters, and Android method channel.
- `lib/pixel_cat.dart`: code-drawn animated pixel cat.
- `android/app/src/main/java/com/remindme/companion/MainActivity.java`: Android bridge to the shared Java pet/reminder service in `../native-core/` at the repository root.
- `test/companion_test.dart`: persistence, task filtering, user interaction, and responsive layout checks.

Run from the repository root:

```sh
./scripts/preview_flutter.sh
./scripts/flutterw analyze
./scripts/flutterw test
```

The browser shows labeled editable sample tasks on first use. Android starts with the private task store already on the phone (empty for a fresh install). No account or cloud backend is required.

The header’s widget icon opens an interactive home-screen widget preview. `lib/task_widget_preview.dart` renders the preview; the Android `TaskWidgetProvider`, `TaskWidgetService`, and `WidgetAddActivity` live in the shared native core. Task-specific platform calls and a task-change event stream keep the app and widget synchronized.
