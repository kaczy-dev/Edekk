import { describe, expect, it } from "vitest";
import { computeQuests, questCompletion } from "./questUtils";
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

describe("computeQuests: collect quests", () => {
  it("is not done while inventory count is below the target", () => {
    const level = makeLevel({
      quests: [{ id: "q1", kind: "collect", itemId: "mouse", count: 3, label: "" }],
    });
    const [status] = computeQuests(level, {
      inventory: { mouse: 2 },
      talked: [],
      levelCompleted: false,
      collected: [],
    });
    expect(status.done).toBe(false);
    expect(status.current).toBe(2);
    expect(status.total).toBe(3);
  });

  it("is done once inventory count reaches the target", () => {
    const level = makeLevel({
      quests: [{ id: "q1", kind: "collect", itemId: "mouse", count: 3, label: "" }],
    });
    const [status] = computeQuests(level, {
      inventory: { mouse: 3 },
      talked: [],
      levelCompleted: false,
      collected: [],
    });
    expect(status.done).toBe(true);
    expect(status.missing).toEqual([]);
  });

  it("caps `current` at the target even with excess inventory", () => {
    const level = makeLevel({
      quests: [{ id: "q1", kind: "collect", itemId: "mouse", count: 2, label: "" }],
    });
    const [status] = computeQuests(level, {
      inventory: { mouse: 99 },
      talked: [],
      levelCompleted: false,
      collected: [],
    });
    expect(status.current).toBe(2);
  });

  it("points a missing-item hint at an uncollected source on the map", () => {
    const level = makeLevel({
      quests: [{ id: "q1", kind: "collect", itemId: "mouse", count: 1, label: "" }],
      objects: [
        { id: "m1", kind: "item", itemId: "mouse", rect: { x: 100, y: 100, w: 10, h: 10 } },
      ],
    });
    const [status] = computeQuests(level, {
      inventory: {},
      talked: [],
      levelCompleted: false,
      collected: [],
    });
    expect(status.missing).toHaveLength(1);
    expect(status.missing[0].where).toContain("mapy");
  });

  it("falls back to an off-map hint when every source is already collected", () => {
    const level = makeLevel({
      quests: [{ id: "q1", kind: "collect", itemId: "mouse", count: 1, label: "" }],
      objects: [
        { id: "m1", kind: "item", itemId: "mouse", rect: { x: 100, y: 100, w: 10, h: 10 } },
      ],
    });
    const [status] = computeQuests(level, {
      inventory: {},
      talked: [],
      levelCompleted: false,
      collected: ["m1"],
    });
    expect(status.missing).toHaveLength(1);
    expect(status.missing[0].where).not.toContain("mapy");
  });
});

describe("computeQuests: talk quests", () => {
  it("is done once the NPC has been talked to", () => {
    const level = makeLevel({
      quests: [{ id: "q1", kind: "talk", objId: "npc1", label: "" }],
      objects: [{ id: "npc1", kind: "npc", rect: { x: 0, y: 0, w: 10, h: 10 } }],
    });
    const [status] = computeQuests(level, {
      inventory: {},
      talked: ["npc1"],
      levelCompleted: false,
      collected: [],
    });
    expect(status.done).toBe(true);
  });

  it("is not done and has no crash when the NPC object is missing from the level", () => {
    const level = makeLevel({
      quests: [{ id: "q1", kind: "talk", objId: "ghost", label: "" }],
    });
    const [status] = computeQuests(level, {
      inventory: {},
      talked: [],
      levelCompleted: false,
      collected: [],
    });
    expect(status.done).toBe(false);
    expect(status.missing).toEqual([]);
  });
});

describe("computeQuests: reach quests", () => {
  it("is ready but not done once requirements are met and the goal hasn't been reached", () => {
    const level = makeLevel({
      quests: [{ id: "q1", kind: "reach", objId: "goal1", label: "" }],
      objects: [
        {
          id: "goal1",
          kind: "goal",
          rect: { x: 0, y: 0, w: 10, h: 10 },
          requires: { key: 1 },
        },
      ],
    });
    const [status] = computeQuests(level, {
      inventory: { key: 1 },
      talked: [],
      levelCompleted: false,
      collected: [],
    });
    expect(status.done).toBe(false);
    expect(status.ready).toBe(true);
  });

  it("is done once the level is marked completed", () => {
    const level = makeLevel({
      quests: [{ id: "q1", kind: "reach", objId: "goal1", label: "" }],
      objects: [{ id: "goal1", kind: "goal", rect: { x: 0, y: 0, w: 10, h: 10 } }],
    });
    const [status] = computeQuests(level, {
      inventory: {},
      talked: [],
      levelCompleted: true,
      collected: [],
    });
    expect(status.done).toBe(true);
    expect(status.missing).toEqual([]);
  });
});

describe("questCompletion", () => {
  it("counts only done statuses", () => {
    const level = makeLevel({
      quests: [
        { id: "q1", kind: "collect", itemId: "mouse", count: 1, label: "" },
        { id: "q2", kind: "collect", itemId: "ball", count: 1, label: "" },
      ],
    });
    const statuses = computeQuests(level, {
      inventory: { mouse: 1 },
      talked: [],
      levelCompleted: false,
      collected: [],
    });
    expect(questCompletion(statuses)).toEqual({ done: 1, total: 2 });
  });
});
