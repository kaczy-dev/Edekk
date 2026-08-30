import { describe, expect, it } from "vitest";
import { dailyDateKey, pickDaily, previousDayKey } from "./daily";

describe("dailyDateKey", () => {
  it("formats as zero-padded YYYY-MM-DD", () => {
    expect(dailyDateKey(new Date(2026, 0, 5))).toBe("2026-01-05");
    expect(dailyDateKey(new Date(2026, 10, 23))).toBe("2026-11-23");
  });
});

describe("previousDayKey", () => {
  it("steps back one calendar day", () => {
    expect(previousDayKey("2026-03-05")).toBe("2026-03-04");
  });

  it("rolls back across a month boundary", () => {
    expect(previousDayKey("2026-03-01")).toBe("2026-02-28");
  });

  it("rolls back across a year boundary", () => {
    expect(previousDayKey("2026-01-01")).toBe("2025-12-31");
  });
});

describe("pickDaily", () => {
  it("returns null for an empty list", () => {
    expect(pickDaily([], new Date(2026, 0, 1))).toBeNull();
  });

  it("is deterministic for the same date and list", () => {
    const items = ["a", "b", "c", "d"];
    const date = new Date(2026, 5, 15);
    expect(pickDaily(items, date)).toBe(pickDaily(items, date));
  });

  it("picks an item that actually belongs to the list", () => {
    const items = ["a", "b", "c"];
    const picked = pickDaily(items, new Date());
    expect(items).toContain(picked);
  });

  it("varies across different dates (not always the same index)", () => {
    const items = ["a", "b", "c", "d", "e", "f", "g", "h"];
    const picks = new Set(
      Array.from({ length: 30 }, (_, i) => pickDaily(items, new Date(2026, 0, 1 + i))),
    );
    // Not a strict guarantee for any hash, but with 8 buckets over 30 days
    // landing on the exact same single item every time would indicate the
    // hash isn't actually varying by date.
    expect(picks.size).toBeGreaterThan(1);
  });
});
