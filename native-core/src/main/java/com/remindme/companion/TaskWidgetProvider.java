package com.remindme.companion;

import android.app.*;
import android.appwidget.*;
import android.content.*;
import android.net.Uri;
import android.os.Build;
import android.widget.RemoteViews;
import java.util.*;

/** A scrollable home-screen task list sharing the app's private task store. */
public class TaskWidgetProvider extends AppWidgetProvider {
  static final String ROW_ACTION = "com.remindme.companion.WIDGET_ACTION";
  static final String TASK_ID = "task_id", OPERATION = "operation";

  static List<Store.Task> pending(Context context) {
    ArrayList<Store.Task> tasks = Store.tasks(context);
    tasks.removeIf(t -> t.done);
    tasks.sort(
        (a, b) ->
            Long.compare(a.due == 0 ? Long.MAX_VALUE : a.due, b.due == 0 ? Long.MAX_VALUE : b.due));
    return tasks;
  }

  static RemoteViews row(Context context, Store.Task task) {
    RemoteViews row = new RemoteViews(context.getPackageName(), R.layout.task_widget_row);
    row.setTextViewText(R.id.widget_title, task.title);
    row.setTextViewText(R.id.widget_detail, task.list);
    row.setContentDescription(R.id.widget_complete, "Complete " + task.title);
    row.setOnClickFillInIntent(
        R.id.widget_complete,
        new Intent().putExtra(TASK_ID, task.id).putExtra(OPERATION, "complete"));
    return row;
  }

  static void update(Context context, AppWidgetManager manager, int id) {
    RemoteViews view = new RemoteViews(context.getPackageName(), R.layout.task_widget);
    List<Store.Task> tasks = pending(context);
    view.setEmptyView(R.id.widget_tasks, R.id.widget_empty);
    view.setOnClickPendingIntent(
        R.id.widget_open,
        PendingIntent.getActivity(
            context,
            id,
            new Intent(context, MainActivity.class)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE));
    view.setOnClickPendingIntent(
        R.id.widget_add,
        PendingIntent.getActivity(
            context,
            id,
            new Intent(context, WidgetAddActivity.class)
                .setData(Uri.parse("remindme://widget/" + id)),
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE));
    Intent action =
        new Intent(context, TaskWidgetProvider.class)
            .setAction(ROW_ACTION)
            .setData(Uri.parse("remindme://widget/actions/" + id));
    // Collection fill-in intents require a mutable template; its explicit component is fixed.
    int flags = PendingIntent.FLAG_UPDATE_CURRENT;
    if (Build.VERSION.SDK_INT >= 31) flags |= PendingIntent.FLAG_MUTABLE;
    view.setPendingIntentTemplate(
        R.id.widget_tasks, PendingIntent.getBroadcast(context, id, action, flags));
    if (Build.VERSION.SDK_INT >= 31 && tasks.size() <= 50) {
      RemoteViews.RemoteCollectionItems.Builder items =
          new RemoteViews.RemoteCollectionItems.Builder()
              .setHasStableIds(false)
              .setViewTypeCount(1);
      for (int i = 0; i < tasks.size(); i++) items.addItem(i, row(context, tasks.get(i)));
      view.setRemoteAdapter(R.id.widget_tasks, items.build());
    } else {
      Intent adapter =
          new Intent(context, TaskWidgetService.class)
              .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id);
      adapter.setData(Uri.parse("remindme://widget/list/" + id));
      view.setRemoteAdapter(R.id.widget_tasks, adapter);
    }
    manager.updateAppWidget(id, view);
  }

  public static void refresh(Context context) {
    AppWidgetManager manager = AppWidgetManager.getInstance(context);
    int[] ids = manager.getAppWidgetIds(new ComponentName(context, TaskWidgetProvider.class));
    for (int id : ids) update(context, manager, id);
    if (ids.length > 0 && (Build.VERSION.SDK_INT < 31 || pending(context).size() > 50))
      manager.notifyAppWidgetViewDataChanged(ids, R.id.widget_tasks);
  }

  @Override
  public void onUpdate(Context context, AppWidgetManager manager, int[] ids) {
    for (int id : ids) update(context, manager, id);
  }

  @Override
  public void onAppWidgetOptionsChanged(
      Context c, AppWidgetManager m, int id, android.os.Bundle options) {
    update(c, m, id);
  }

  @Override
  public void onReceive(Context context, Intent intent) {
    super.onReceive(context, intent);
    if (!ROW_ACTION.equals(intent.getAction())) return;
    String id = intent.getStringExtra(TASK_ID);
    if (id == null) return;
    if ("complete".equals(intent.getStringExtra(OPERATION))) Store.complete(context, id);
    else if ("delete".equals(intent.getStringExtra(OPERATION))) Store.remove(context, id);
  }
}
