package com.remindme.companion;

import android.content.Context;
import java.util.*;
import org.json.*;

/** Durable companion designs, voice choices, and per-app reminder rules. */
public final class PetProfile {
  public String id = "mochi",
      name = "Mochi",
      animal = "cat",
      font = "rounded",
      entry = "left",
      position = "center",
      vertical = "bottom",
      taskClip = "",
      timerClip = "";
  public int color = 0xFFD99458,
      accent = 0xFFFFE4BB,
      textColor = 0xFF293E34,
      bubbleColor = 0xFFFFFCF3;
  public float size = 88,
      fontSize = 15,
      radius = 20,
      opacity = 1,
      speed = 90,
      holdSeconds = 12,
      volume = .8f,
      rate = 1,
      pitch = 1;
  public boolean voiceEnabled, readText;

  static float number(JSONObject o, String key, float fallback, float low, float high) {
    return Math.max(low, Math.min(high, (float) o.optDouble(key, fallback)));
  }

  public static PetProfile from(JSONObject o) {
    PetProfile p = new PetProfile();
    p.id = o.optString("id", "mochi");
    p.name = o.optString("name", "Mochi");
    p.animal = o.optString("animal", "cat");
    p.font = o.optString("font", "rounded");
    p.entry = o.optString("entry", "left");
    p.position = o.optString("position", "center");
    p.vertical = o.optString("vertical", "bottom");
    p.color = o.optInt("color", p.color);
    p.accent = o.optInt("accent", p.accent);
    p.textColor = o.optInt("textColor", p.textColor);
    p.bubbleColor = o.optInt("bubbleColor", p.bubbleColor);
    p.size = number(o, "size", 88, 48, 160);
    p.fontSize = number(o, "fontSize", 15, 12, 24);
    p.radius = number(o, "radius", 20, 8, 28);
    p.opacity = number(o, "opacity", 1, .7f, 1);
    p.speed = number(o, "speed", 90, 40, 160);
    p.holdSeconds = number(o, "holdSeconds", 12, 5, 40);
    p.volume = number(o, "volume", .8f, 0, 1);
    p.rate = number(o, "rate", 1, .7f, 1.4f);
    p.pitch = number(o, "pitch", 1, .7f, 1.4f);
    p.voiceEnabled = o.optBoolean("voiceEnabled");
    p.readText = o.optBoolean("readText");
    p.taskClip = o.optString("taskClip", "");
    p.timerClip = o.optString("timerClip", "");
    return p;
  }

  public static JSONArray companions(Context c) {
    try {
      JSONArray a = new JSONArray(Store.prefs(c).getString("companions", "[]"));
      if (a.length() > 0) return a;
    } catch (JSONException ignored) {
    }
    JSONArray a = new JSONArray();
    JSONObject p = new JSONObject();
    try {
      p.put("id", "mochi")
          .put("name", "Mochi")
          .put("animal", "cat")
          .put("voiceEnabled", Store.prefs(c).getBoolean("speech", false));
    } catch (JSONException ignored) {
    }
    return a.put(p);
  }

  public static PetProfile resolve(Context c, String id) {
    JSONArray a = companions(c);
    PetProfile fallback = new PetProfile();
    for (int i = 0; i < a.length(); i++) {
      JSONObject o = a.optJSONObject(i);
      if (o == null) continue;
      PetProfile p = from(o);
      if (i == 0) fallback = p;
      if (p.id.equals(id)) return p;
    }
    return fallback;
  }

  public static String defaultId(Context c) {
    String id = Store.prefs(c).getString("defaultCompanion", "mochi");
    return resolve(c, id).id;
  }

  public static boolean exists(Context c, String id) {
    JSONArray a = companions(c);
    for (int i = 0; i < a.length(); i++)
      if (a.optJSONObject(i) != null && id.equals(a.optJSONObject(i).optString("id"))) return true;
    return false;
  }

  public static JSONArray timerJson(Context c) {
    try {
      if (Store.prefs(c).contains("timers"))
        return new JSONArray(Store.prefs(c).getString("timers", "[]"));
      JSONArray a = new JSONArray();
      Set<String> watched = Store.prefs(c).getStringSet("watched", Collections.emptySet());
      if (!watched.isEmpty())
        a.put(
            new JSONObject()
                .put("id", "legacy-timer")
                .put("name", "A scrolling break")
                .put("minutes", Store.prefs(c).getInt("minutes", 20))
                .put("enabled", Store.prefs(c).getBoolean("nudges", false))
                .put("companionId", defaultId(c))
                .put("apps", new JSONArray(watched)));
      return a;
    } catch (JSONException ignored) {
      return new JSONArray();
    }
  }

  public static final class Rule {
    public String id, name, companionId;
    public int minutes;
    public boolean enabled;
    public Set<String> apps = new HashSet<>();

    public String fingerprint() {
      return companionId + ":" + minutes + ":" + enabled + ":" + apps.hashCode();
    }
  }

  public static List<Rule> rules(Context c) {
    ArrayList<Rule> out = new ArrayList<>();
    JSONArray a = timerJson(c);
    for (int i = 0; i < a.length(); i++) {
      JSONObject o = a.optJSONObject(i);
      if (o == null) continue;
      Rule r = new Rule();
      r.id = o.optString("id");
      r.name = o.optString("name", "A scrolling break");
      r.companionId = o.optString("companionId", defaultId(c));
      r.minutes = Math.max(5, Math.min(120, o.optInt("minutes", 20)));
      r.enabled = o.optBoolean("enabled", true);
      JSONArray apps = o.optJSONArray("apps");
      if (apps != null) for (int n = 0; n < apps.length(); n++) r.apps.add(apps.optString(n));
      out.add(r);
    }
    return out;
  }

  public static Object decode(Object value) throws JSONException {
    if (value == JSONObject.NULL) return null;
    if (value instanceof JSONObject) {
      JSONObject o = (JSONObject) value;
      Map<String, Object> out = new HashMap<>();
      Iterator<String> keys = o.keys();
      while (keys.hasNext()) {
        String key = keys.next();
        out.put(key, decode(o.get(key)));
      }
      return out;
    }
    if (value instanceof JSONArray) {
      JSONArray a = (JSONArray) value;
      ArrayList<Object> out = new ArrayList<>();
      for (int i = 0; i < a.length(); i++) out.add(decode(a.get(i)));
      return out;
    }
    return value;
  }
}
