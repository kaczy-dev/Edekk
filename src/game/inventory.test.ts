import { describe, expect, it } from "vitest";
import { NPC_GIFTS, giftObjId, inventoryFromCollected } from "./inventory";
import type { LevelDef } from "./types";

function makeLevel(overrides: Partial<LevelDef> = {}): LevelDef {
  return {
    id: "t1",
    slug: "test",
    title: "Test Level",
    subtitle: "",
    background: "",
    width: 1000,
    height: 1000,
    spawn: { x: 0, y: 0 },
    intro: "",
    objective: "",
    unlockHint: "",
    quests: [],
    objects: [],
    ...overrides,
  };
}

describe("inventoryFromCollected", () => {
  it("counts each collected map item once", () => {
    const level = makeLevel({
      objects: [
        { id: "m1", kind: "item", itemId: "mouse", rect: { x: 0, y: 0, w: 10, h: 10 } },
        { id: "m2", kind: "item", itemId: "mouse", rect: { x: 0, y: 0, w: 10, h: 10 } },
        { id: "b1", kind: "item", itemId: "ball", rect: { x: 0, y: 0, w: 10, h: 10 } },
      ],
    });
    const inventory = inventoryFromCollected(level, ["m1", "m2", "b1"]);
    expect(inventory).toEqual({ mouse: 2, ball: 1 });
  });

  it("resolves an NPC gift id back to the item it grants", () => {
    const level = makeLevel({
      objects: [
        { id: "squirrel", kind: "npc", npcId: "squirrel", rect: { x: 0, y: 0, w: 10, h: 10 } },
      ],
    });
    const inventory = inventoryFromCollected(level, [giftObjId("squirrel")]);
    expect(inventory).toEqual({ [NPC_GIFTS.squirrel]: 1 });
  });

  it("ignores an id that matches nothing in the level (stale save data)", () => {
    const level = makeLevel();
    const inventory = inventoryFromCollected(level, ["does-not-exist"]);
    expect(inventory).toEqual({});
  });

  it("ignores a gift id whose NPC has no entry in NPC_GIFTS", () => {
    const level = makeLevel({
      objects: [
        {
          id: "stranger",
          kind: "npc",
          npcId: "unregistered-npc",
          rect: { x: 0, y: 0, w: 10, h: 10 },
        },
      ],
    });
    const inventory = inventoryFromCollected(level, [giftObjId("stranger")]);
    expect(inventory).toEqual({});
  });

  it("returns an empty inventory for an empty collected list", () => {
    expect(inventoryFromCollected(makeLevel(), [])).toEqual({});
  });
});
