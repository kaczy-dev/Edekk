import { describe, expect, it } from "vitest";
import { inventoryFromCollected, giftObjId, NPC_GIFTS } from "./inventory";
import { getLevel } from "./levels";

const level1 = getLevel("1")!;

describe("inventoryFromCollected", () => {
  it("tallies picked-up items by their itemId", () => {
    const inv = inventoryFromCollected(level1, ["i-ball", "i-treat"]);
    expect(inv.ball).toBe(1);
    expect(inv.treat).toBe(1);
  });

  it("ignores unknown/stale object ids instead of throwing", () => {
    const inv = inventoryFromCollected(level1, ["not-a-real-object-id"]);
    expect(inv).toEqual({});
  });

  it("resolves an NPC gift id (npcObjId + '-gift') back to the granted ItemId", () => {
    const level2 = getLevel("2")!;
    const inv = inventoryFromCollected(level2, [giftObjId("squirrel")]);
    expect(inv[NPC_GIFTS.squirrel]).toBe(1);
  });
});

describe("giftObjId", () => {
  it("is stable and reversible via the '-gift' suffix convention", () => {
    expect(giftObjId("pigeon")).toBe("pigeon-gift");
  });
});
