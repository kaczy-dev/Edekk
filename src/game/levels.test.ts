import { describe, expect, it } from "vitest";
import { LEVELS } from "./levels";
import type { Rect } from "./types";

function overlaps(a: Rect, b: Rect): boolean {
  return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

// Regression coverage for a real bug: the Level 1 "entrance" goal rect was
// placed fully inside the "building2" obstacle rect after a background
// merge, so the cat could never physically reach it and Space/E did nothing
// — looked like a broken interact key, but was actually unreachable geometry.
describe("level geometry", () => {
  for (const level of LEVELS) {
    const obstacles = level.objects.filter((o) => o.kind === "obstacle");
    const interactables = level.objects.filter(
      (o) => o.kind === "item" || o.kind === "npc" || o.kind === "goal",
    );

    it(`${level.slug}: no item/npc/goal is embedded inside an obstacle`, () => {
      for (const target of interactables) {
        for (const obstacle of obstacles) {
          const overlapArea = rectOverlapArea(target.rect, obstacle.rect);
          const targetArea = target.rect.w * target.rect.h;
          // Flag only near-total overlap (the object's center, and most of
          // its area, buried in the wall) — a light edge clip against a
          // border obstacle is normal level design, not a placement bug.
          expect(
            overlapArea / targetArea,
            `"${target.id}" (${target.kind}) is ${Math.round((overlapArea / targetArea) * 100)}% inside obstacle "${obstacle.id}" — likely unreachable`,
          ).toBeLessThan(0.8);
        }
      }
    });

    it(`${level.slug}: spawn point is not inside an obstacle`, () => {
      const spawnRect: Rect = { x: level.spawn.x - 1, y: level.spawn.y - 1, w: 2, h: 2 };
      for (const obstacle of obstacles) {
        expect(
          overlaps(spawnRect, obstacle.rect),
          `spawn is inside obstacle "${obstacle.id}"`,
        ).toBe(false);
      }
    });

    it(`${level.slug}: every object stays within level bounds`, () => {
      for (const obj of level.objects) {
        expect(obj.rect.x).toBeGreaterThanOrEqual(0);
        expect(obj.rect.y).toBeGreaterThanOrEqual(0);
        expect(obj.rect.x + obj.rect.w).toBeLessThanOrEqual(level.width);
        expect(obj.rect.y + obj.rect.h).toBeLessThanOrEqual(level.height);
      }
    });

    it(`${level.slug}: quest objId/itemId references resolve to real objects`, () => {
      for (const q of level.quests) {
        if (q.kind === "collect") {
          const hasSource = level.objects.some((o) => o.kind === "item" && o.itemId === q.itemId);
          expect(
            hasSource,
            `quest "${q.id}" wants "${q.itemId}" but no matching item object exists on ${level.slug}`,
          ).toBe(true);
        } else {
          const target = level.objects.find((o) => o.id === q.objId);
          expect(target, `quest "${q.id}" references missing object "${q.objId}"`).toBeDefined();
        }
      }
    });
  }
});

function rectOverlapArea(a: Rect, b: Rect): number {
  const w = Math.max(0, Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x));
  const h = Math.max(0, Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y));
  return w * h;
}
