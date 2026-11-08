package com.remindme.companion;

import android.app.*;
import android.os.Bundle;
import android.view.*;
import android.widget.*;

/** Small quick-add dialog launched directly from the home-screen widget. */
public class WidgetAddActivity extends Activity {
  @Override
  public void onCreate(Bundle state) {
    super.onCreate(state);
    LinearLayout form = new LinearLayout(this);
    form.setOrientation(LinearLayout.VERTICAL);
    int padding = (int) (24 * getResources().getDisplayMetrics().density);
    form.setPadding(padding, padding / 2, padding, 0);
    EditText title = new EditText(this);
    title.setHint("What would you like to get done?");
    title.setInputType(
        android.text.InputType.TYPE_CLASS_TEXT
            | android.text.InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
    title.setSingleLine(true);
    title.setFilters(
        new android.text.InputFilter[] {new android.text.InputFilter.LengthFilter(200)});
    form.addView(title);
    EditText list = new EditText(this);
    list.setHint("List");
    list.setText("Personal");
    list.setSingleLine(true);
    list.setFilters(new android.text.InputFilter[] {new android.text.InputFilter.LengthFilter(40)});
    form.addView(list);
    if (state != null) {
      title.setText(state.getString("title", ""));
      list.setText(state.getString("list", "Personal"));
    }
    AlertDialog dialog =
        new AlertDialog.Builder(this, R.style.WidgetQuickAddDialogTheme)
            .setTitle("A new small step")
            .setView(form)
            .setPositiveButton("Add task", null)
            .setNegativeButton("Cancel", (d, w) -> finish())
            .setOnCancelListener(d -> finish())
            .create();
    dialog.setOnShowListener(
        d -> {
          dialog
              .getButton(AlertDialog.BUTTON_POSITIVE)
              .setOnClickListener(
                  v -> {
                    String name = title.getText().toString().trim();
                    if (name.isEmpty()) {
                      title.setError("Give your task a name");
                      return;
                    }
                    String group = list.getText().toString().trim();
                    Store.upsert(
                        this, new Store.Task(name, 0, group.isEmpty() ? "Personal" : group));
                    finish();
                  });
          title.requestFocus();
          dialog
              .getWindow()
              .setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE);
        });
    dialog.show();
    this.titleInput = title;
    this.listInput = list;
  }

  private EditText titleInput, listInput;

  @Override
  protected void onSaveInstanceState(Bundle state) {
    super.onSaveInstanceState(state);
    if (titleInput != null) {
      state.putString("title", titleInput.getText().toString());
      state.putString("list", listInput.getText().toString());
    }
  }
}
