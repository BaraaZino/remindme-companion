# RemindMe Companion

A Flutter task app with **Mochi**, a pixel cat that offers gentle reminders and phone-use nudges. The Flutter project is in `companion_flutter/`. Android-specific functionality uses a method channel and the shared Java code in `native-core/`.

## Develop with a live preview

```sh
# Run from the repository root, with Flutter stable installed:
./scripts/flutterw pub get
./scripts/preview_flutter.sh
```

Open **http://127.0.0.1:8942** in the Codex in-app browser or a regular browser. Flutter renders the actual Dart interface. Edit `companion_flutter/lib/`, then use the running Flutter terminal’s hot reload/restart commands. The wide browser layout includes a preview introduction alongside the phone layout; narrow windows show the app alone. Stop the server with Ctrl-C.

The browser version has labeled example tasks, local persistence, task editing/completion, reminder-date selection, configurable nudge settings, and interactive pet bubbles. Use **Clear** beneath the example tasks to start empty. Browser reminders only run while the page is open. **Wake Mochi** simulates the floating pet inside the app; it cannot float over other browser tabs or desktop apps. Usage tracking and speech are Android features. No usage data is collected by the web preview.

For Android, open `companion_flutter/` in Android Studio or VS Code with the Flutter extension, connect a phone/emulator, then run `./scripts/flutterw run` from the repository root. Use `./scripts/flutterw build apk --debug` for a Flutter APK. Android needs the SDK versions specified by the generated Flutter Gradle project. The Android application ID remains `com.remindme.companion`, and the bridge reuses the original private task store.

```sh
./scripts/flutterw analyze
./scripts/flutterw test
```

The old `dist/RemindMe-Companion.apk` is the initial **Java** version, not the Flutter build. The original Java interface remains in `app/` for reference and can still be built with `python3 scripts/build_apk.py`. Both Android interfaces use `native-core/` for reminder scheduling, overlay behavior, task storage, and usage timing. The Flutter browser build does not execute that Android code.

## Original Android APK

## Install and use

1. Transfer `dist/RemindMe-Companion.apk` to your Android phone and open it. Allow installation from that source if Android asks. This is a locally signed development build.
2. Open RemindMe Companion and allow notifications for task reminders.
3. Add a task and optionally select a future reminder date and time. Use a list name such as Personal or Work. Tap a task to edit or delete it; tick its checkbox to complete it.
4. Tap **Let Mochi walk with me**, allow display over other apps, return to the app, and tap the start button again.
5. Under **Companion**, optionally enable phone-use nudges, grant usage access, select apps, and set your interval from 5 to 120 minutes. Nudges count consecutive time across selected apps, excluding short activity transitions. Leaving those apps or locking the screen resets the session. Tracking runs only while Mochi is active.
6. Tap Mochi for your next task, drag to reposition, or hold and release to pause. The ongoing notification also has a Pause action. Reminder bubbles offer Done, Snooze for 10 minutes, and Dismiss. Optional speech uses Android text-to-speech.

**Today** includes unfinished undated tasks, overdue tasks, and tasks due today. **All tasks** also includes future and completed tasks. No sample tasks are inserted.

## Reminder behavior and limitations

Dated tasks generate notifications even when the companion is paused. An active companion also shows a bubble. Android's battery-saving and alarm scheduling may delay reminders: this is not an exact-alarm app. Due tasks that were missed are delivered after the device restarts; the visible companion must be started manually again. Force-stopping the app prevents reminders until it is opened again. Some manufacturers require additional battery settings for persistent overlays. Secure screens and apps may hide overlays.

This initial version has named task lists, one-time reminders, and task completion. Recurring tasks, subtasks, cloud sync, and Microsoft To Do integration are not included.

## Build

Requires Python 3 and JDK 17 or newer. Either install Android SDK platform 35 and build-tools 35.0.0 and set `ANDROID_HOME`, or fetch the official SDK packages with:

```sh
python3 scripts/bootstrap_android.py
python3 scripts/build_apk.py
```

The build script compiles resources, compiles Java, produces DEX, aligns the APK, signs it with a local development key stored in `.tools/debug.keystore`, and verifies the signature. Keep that key to install future builds over this one. The SDK packages and keys are ignored by git. A Gradle project is also included for Android Studio.

Run the phone-use session tests:

```sh
mkdir -p build/tests
javac -d build/tests native-core/src/main/java/com/remindme/companion/UsageSession.java tests/UsageSessionTest.java
java -cp build/tests UsageSessionTest
```

## Device checks before relying on reminders

- Start the companion; switch to another app; check that the cat walks and can be dragged, tapped, and paused.
- Add a task due in a few minutes. Check the notification and pet bubble, completion, and snoozing. Repeat with the pet paused.
- Grant usage access, select an app, set five minutes, and keep using it. Check the nudge; repeat with a screen lock and an unselected app to check reset behavior.
- Deny overlay or usage access and check the corresponding setup guidance. Check notification-denied behavior and restart the phone.

The Java timer tests and APK compilation/signature checks do not replace these device tests.
