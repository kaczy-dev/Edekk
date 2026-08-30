import { describe, expect, it } from "vitest";
import { computeQuests, questCompletion } from "./questUtils";
import { LEVELS, getLevel } from "./levels";

const level1 = getLevel("1")!;

describe("computeQuests", () => {
  it("marks a collect quest done once the item count is reached", () => {
    const [ballQuest] = computeQuests(level1, {
      inventory: { ball: 1 },
      talked: [],
      levelCompleted: false,
      collected: [],
    });
    expect(ballQuest.done).toBe(true);
    expect(ballQuest.current).toBe(1);
    expect(ballQuest.total).toBe(1);
  });

  it("leaves a collect quest not-done and reports a hint when short", () => {
    const [ballQuest] = computeQuests(level1, {
      inventory: {},
      talked: [],
      levelCompleted: false,
      collected: [],
    });
    expect(ballQuest.done).toBe(false);
    expect(ballQuest.current).toBe(0);
    expect(ballQuest.missing.length).toBeGreaterThan(0);
  });

  it("caps `current` at the required count even with excess inventory", () => {
    const [ballQuest] = computeQuests(level1, {
      inventory: { ball: 99 },
      talked: [],
      levelCompleted: false,
      collected: [],
    });
    expect(ballQuest.current).toBe(1);
  });

  it("marks a talk quest done only once the npc id is in `talked`", () => {
    const level2 = getLevel("2")!;
    const [, squirrelQuest] = computeQuests(level2, {
      inventory: {},
      talked: ["squirrel"],
      levelCompleted: false,
      collected: [],
    });
    expect(squirrelQuest.done).toBe(true);
  });

  it("a reach quest is 'ready' once requirements are met but not yet completed", () => {
    const [, , reachQuest] = computeQuests(level1, {
      inventory: { ball: 1, treat: 1 },
      talked: [],
      levelCompleted: false,
      collected: [],
    });
    expect(reachQuest.ready).toBe(true);
    expect(reachQuest.done).toBe(false);
  });

  it("a reach quest is done once `levelCompleted` is true, regardless of inventory", () => {
    const [, , reachQuest] = computeQuests(level1, {
      inventory: {},
      talked: [],
      levelCompleted: true,
      collected: [],
    });
    expect(reachQuest.done).toBe(true);
  });
});

describe("questCompletion", () => {
  it("counts done vs total across every level's real quest list", () => {
    for (const level of LEVELS) {
      const statuses = computeQuests(level, {
        inventory: {},
        talked: [],
        levelCompleted: false,
        collected: [],
      });
      const { done, total } = questCompletion(statuses);
      expect(total).toBe(level.quests.length);
      expect(done).toBe(0);
    }
  });
});
