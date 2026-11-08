import com.remindme.companion.UsageSession;
import java.util.Set;

public final class UsageSessionTest {
  static void equal(long expected, long actual, String scenario) {
    if (expected != actual) throw new AssertionError(scenario + ": " + actual + " != " + expected);
  }

  public static void main(String[] args) {
    Set<String> watched = Set.of("social", "video");
    UsageSession s = new UsageSession(1000);
    s.resume("social", 1000, watched);
    s.advance(601000, watched);
    equal(600000, s.elapsed(), "ten minutes of selected app");
    s.pause("social", 601000, watched);
    s.resume("video", 601200, watched);
    s.advance(1201200, watched);
    equal(1200000, s.elapsed(), "switching selected apps retains session and excludes transition");
    s.resume("reader", 1201200, watched);
    equal(0, s.elapsed(), "unselected app resets session");
    s.resume("video", 1300000, watched);
    s.advance(1360000, watched);
    s.pause("video", 1360000, watched);
    s.advance(1365000, watched);
    equal(0, s.elapsed(), "leaving app without next resume resets session");
    s.resume("video", 1400000, watched);
    s.advance(1460000, watched);
    s.reset(1460000);
    equal(0, s.elapsed(), "screen lock resets session");
    s.resume("social", 1500000, watched);
    s.advance(1560000, Set.of());
    equal(0, s.elapsed(), "removing a selected app stops counting");
    System.out.println("Passed 6 usage-session scenarios.");
  }
}
