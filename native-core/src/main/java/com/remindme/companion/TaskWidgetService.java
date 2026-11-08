package com.remindme.companion;

import android.content.*;
import android.widget.*;
import java.util.*;

/** Collection adapter for Android 8–11 and large lists on newer launchers. */
public class TaskWidgetService extends RemoteViewsService {
  @Override
  public RemoteViewsFactory onGetViewFactory(Intent intent) {
    return new RemoteViewsFactory() {
      private List<Store.Task> tasks = Collections.emptyList();

      public void onCreate() {
        onDataSetChanged();
      }

      public void onDataSetChanged() {
        tasks = TaskWidgetProvider.pending(TaskWidgetService.this);
      }

      public void onDestroy() {
        tasks = Collections.emptyList();
      }

      public int getCount() {
        return tasks.size();
      }

      public RemoteViews getViewAt(int position) {
        return position >= 0 && position < tasks.size()
            ? TaskWidgetProvider.row(TaskWidgetService.this, tasks.get(position))
            : null;
      }

      public RemoteViews getLoadingView() {
        return null;
      }

      public int getViewTypeCount() {
        return 1;
      }

      public long getItemId(int position) {
        return position;
      }

      public boolean hasStableIds() {
        return false;
      }
    };
  }
}
