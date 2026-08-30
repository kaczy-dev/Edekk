import { describe, expect, it } from "vitest";
import { LEVELS } from "./levels";
import { ITEMS } from "./items";
import { NPC_GIFTS } from "./inventory";

// Cheap, Phaser-free sanity checks on the level data itself. These don't
// boot a scene, but they do catch the class of authoring bug that's easy to
// introduce by hand-editing levels.ts: a quest/goal pointing at an object id
// that doesn't exist, or an item id with no ITEMS entry (which would render
// as a broken "❓" glyph and a crash-prone lookup at runtime).
describe.each(LEVELS)("level $id ($title)", (level) => {
  const objectIds = new Set(level.objects.map((o) => o.id));

  it("has unique object ids", () => {
    expect(objectIds.size).toBe(level.objects.length);
  });

  it("every quest referencing an object id points at a real object", () => {
    for (const q of level.quests) {
      if (q.kind === "talk" || q.kind === "reach") {
        expect(objectIds.has(q.objId), `quest "${q.id}" -> missing object "${q.objId}"`).toBe(true);
      }
    }
  });

  it("every quest referencing an itemId has a matching ITEMS entry", () => {
    for (const q of level.quests) {
      if (q.kind === "collect") {
        expect(ITEMS[q.itemId], `quest "${q.id}" -> unknown itemId "${q.itemId}"`).toBeDefined();
      }
    }
  });

  it("every item object's itemId has a matching ITEMS entry", () => {
    for (const obj of level.objects) {
      if (obj.kind === "item" && obj.itemId) {
        expect(
          ITEMS[obj.itemId],
          `object "${obj.id}" -> unknown itemId "${obj.itemId}"`,
        ).toBeDefined();
      }
    }
  });

  it("every goal's `requires` only names known items", () => {
    for (const obj of level.objects) {
      if (obj.kind === "goal" && obj.requires) {
        for (const itemId of Object.keys(obj.requires)) {
          expect(
            ITEMS[itemId as keyof typeof ITEMS],
            `goal "${obj.id}" requires unknown item "${itemId}"`,
          ).toBeDefined();
        }
      }
    }
  });

  it("every NPC's npcId with a registered gift resolves to a real item", () => {
    for (const obj of level.objects) {
      if (obj.kind === "npc" && obj.npcId && obj.npcId in NPC_GIFTS) {
        const giftItemId = NPC_GIFTS[obj.npcId];
        expect(
          ITEMS[giftItemId],
          `npc "${obj.id}" gift -> unknown itemId "${giftItemId}"`,
        ).toBeDefined();
      }
    }
  });

  it("a patrolling NPC has a positive range", () => {
    for (const obj of level.objects) {
      if (obj.kind === "npc" && obj.patrol) {
        expect(obj.patrol.range, `npc "${obj.id}" patrol range must be positive`).toBeGreaterThan(
          0,
        );
      }
    }
  });
});

describe("LEVELS overall", () => {
  it("has unique level ids", () => {
    const ids = LEVELS.map((l) => l.id);
    expect(new Set(ids).size).toBe(ids.length);
  });
});
