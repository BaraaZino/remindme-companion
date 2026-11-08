# RemindMe Companion

An Android to-do app with **Mochi**, a pixel cat that walks over other apps, offers task reminders, and gently checks in during long sessions in selected apps. Android 8.0 or newer. All data stays on the device; no accounts, server, analytics, or internet permission.

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
javac -d build/tests app/src/main/java/com/remindme/companion/UsageSession.java tests/UsageSessionTest.java
java -cp build/tests UsageSessionTest
```

## Device checks before relying on reminders

- Start the companion; switch to another app; check that the cat walks and can be dragged, tapped, and paused.
- Add a task due in a few minutes. Check the notification and pet bubble, completion, and snoozing. Repeat with the pet paused.
- Grant usage access, select an app, set five minutes, and keep using it. Check the nudge; repeat with a screen lock and an unselected app to check reset behavior.
- Deny overlay or usage access and check the corresponding setup guidance. Check notification-denied behavior and restart the phone.

The Java timer tests and APK compilation/signature checks do not replace these device tests.
