package com.remindme.companion;

import android.content.Context;
import android.graphics.*;
import android.view.View;

/** Code-drawn animal designs shared conceptually with the Flutter painter. */
public class CatView extends View {
  private final Paint paint = new Paint();
  public boolean walking = true, faceRight = true, talking;
  public PetProfile profile = new PetProfile();

  public CatView(Context c) {
    super(c);
  }

  public void setProfile(PetProfile p) {
    profile = p;
    setContentDescription(p.name + ", your " + p.animal + " companion");
    invalidate();
  }

  void r(Canvas c, int color, float x, float y, float w, float h) {
    paint.setColor(color);
    c.drawRect(x, y, x + w, y + h, paint);
  }

  @Override
  protected void onDraw(Canvas c) {
    super.onDraw(c);
    c.save();
    float scale = Math.min(getWidth() / 36f, getHeight() / 40f);
    c.translate((getWidth() - 36 * scale) / 2, (getHeight() - 40 * scale) / 2);
    c.scale(scale, scale);
    if (!faceRight) {
      c.translate(36, 0);
      c.scale(-1, 1);
    }
    int fur = profile.color, accent = profile.accent, ink = 0xFF483A2E;
    int step = walking ? (int) (System.currentTimeMillis() / 180 % 2) : 0;
    String animal = profile.animal;
    r(c, 0x18365B45, 5, 37, 26, 1);
    r(c, fur, 5, 25, 23, 9);
    r(c, fur, 12, 15, 18, 14);
    if ("bunny".equals(animal)) {
      r(c, fur, 13, 2, 5, 15);
      r(c, fur, 24, 2, 5, 15);
      r(c, accent, 14, 4, 3, 11);
      r(c, accent, 25, 4, 3, 11);
      r(c, accent, 1, 27, 6, 6);
    } else if ("dog".equals(animal)) {
      r(c, accent, 9, 14, 6, 15);
      r(c, accent, 27, 14, 6, 15);
      r(c, fur, 1, 20 + step, 5, 13);
    } else {
      r(c, fur, 12, 9, 5, 9);
      r(c, fur, 25, 9, 5, 9);
      r(c, accent, 13, 11, 3, 5);
      r(c, accent, 26, 11, 3, 5);
      r(c, fur, 2, 21, 4, 12);
      r(c, fur, 0, 16 + step, 4, 9);
      if ("fox".equals(animal)) r(c, accent, 0, 16 + step, 4, 5);
    }
    if ("cat".equals(animal)) {
      r(c, accent, 17, 15, 2, 5);
      r(c, accent, 23, 15, 2, 5);
      r(c, accent, 7, 26, 3, 5);
    }
    r(c, ink, 17, 22, 2, 3);
    r(c, ink, 26, 22, 2, 3);
    r(c, accent, 19, 27, 8, 4);
    r(c, ink, 22, 27, 2, 1);
    r(c, ink, 23, 29, 2, talking && (System.currentTimeMillis() / 250 % 2 == 0) ? 3 : 1);
    r(c, fur, 9 + step, 33, 4, 3 - step);
    r(c, fur, 24 - step, 33, 4, 2 + step);
    r(c, accent, 9 + step, 35 - step, 4, 1);
    r(c, accent, 24 - step, 34 + step, 4, 1);
    c.restore();
    if (walking || talking) postInvalidateDelayed(120);
  }
}
