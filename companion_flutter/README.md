# RemindMe · Flutter

The active Flutter app lives here. Start with the [repository guide](../README.md) for features, build commands, architecture, and a beginner-friendly reading order.

Run from the repository root:

```sh
./scripts/preview_flutter.sh
./scripts/flutterw analyze
./scripts/flutterw test
./scripts/build_flutter_apk.sh
```

The bottom tabs are Tasks, Companions, and App timers. Each task and timer stores a companion ID. Companion settings include animal design, size, colors, bubble typography, visit motion, and separate recorded/imported audio clips for task and timer reminders.

Android task/calendar/scheduler/widget logic is in the shared `../native-core/` folder. Android-specific Flutter bridge, foreground speech, and recording code are in `android/app/src/main/java/com/remindme/companion/`. Companion visits stay inside RemindMe on all devices. The browser uses browser audio APIs; phone calendars and phone usage monitoring require Android. Dated tasks support daily reminders plus custom final offsets, and can link one way to a writable phone calendar.
