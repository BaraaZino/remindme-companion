package com.remindme.companion;

import android.content.Context;
import android.graphics.*;
import android.view.View;

public class CatView extends View {
  private final Paint p = new Paint();
  public boolean walking = true, faceRight = true;

  public CatView(Context c) {
    super(c);
    setContentDescription(
        "Mochi, your pixel cat companion. Tap for a task, drag to move, or hold to pause.");
  }

  void r(Canvas c, int color, float x, float y, float w, float h) {
    p.setColor(color);
    c.drawRect(x, y, x + w, y + h, p);
  }

  @Override
  protected void onDraw(Canvas canvas) {
    super.onDraw(canvas);
    Canvas c = canvas;
    c.save();
    float s = Math.min(getWidth() / 32f, getHeight() / 30f);
    c.translate((getWidth() - 32 * s) / 2, (getHeight() - 30 * s) / 2);
    c.scale(s, s);
    if (!faceRight) {
      c.translate(32, 0);
      c.scale(-1, 1);
    }
    int fur = Color.rgb(216, 147, 84), dark = Color.rgb(156, 94, 51), ink = Color.rgb(57, 48, 42);
    int step = walking ? (int) (System.currentTimeMillis() / 220 % 2) : 0;
    r(c, 0x18315D50, 5, 28, 23, 1);
    r(c, fur, 4, 17, 22, 9);
    r(c, fur, 11, 8, 17, 13);
    r(c, fur, 11, 3, 5, 7);
    r(c, fur, 23, 3, 5, 7);
    r(c, 0xFFE8B69A, 12, 5, 3, 4);
    r(c, 0xFFE8B69A, 24, 5, 3, 4);
    r(c, fur, 1, 13, 4, 10);
    r(c, fur, 0, 10, 3, 5);
    r(c, dark, 7, 18, 3, 4);
    r(c, dark, 16, 9, 2, 4);
    r(c, dark, 21, 9, 2, 3);
    r(c, ink, 16, 14, 2, 3);
    r(c, ink, 24, 14, 2, 3);
    r(c, 0xFFF7D5B0, 18, 19, 7, 3);
    r(c, ink, 21, 19, 2, 1);
    r(c, fur, 7 + step, 25, 4, 3 - step);
    r(c, fur, 21 - step, 25, 4, 2 + step);
    c.restore();
    if (walking) postInvalidateDelayed(160);
  }
}
