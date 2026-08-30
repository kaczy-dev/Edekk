/** Deterministic day key in the player's local timezone (YYYY-MM-DD). */
export function dailyDateKey(date: Date = new Date()): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/** Simple string hash (djb2-ish), pure and stable across sessions/devices for the same date key. */
function hashKey(key: string): number {
  let hash = 5381;
  for (let i = 0; i < key.length; i++) hash = (hash * 33 + key.charCodeAt(i)) >>> 0;
  return hash;
}

/** Picks today's featured item deterministically from a list, based on the local date. */
export function pickDaily<T>(items: T[], date: Date = new Date()): T | null {
  if (items.length === 0) return null;
  return items[hashKey(dailyDateKey(date)) % items.length];
}

/** Yesterday's day key, for streak continuity checks. */
export function previousDayKey(dateKey: string): string {
  const [y, m, d] = dateKey.split("-").map(Number);
  const prev = new Date(y, m - 1, d - 1);
  return dailyDateKey(prev);
}
