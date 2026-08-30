import { beforeEach, describe, expect, it } from "vitest";
import { useGameStore, DIFFICULTIES } from "./gameStore";

// Zustand stores are module-singletons; reset to a clean slate before every
// test so cases can't leak state into each other via import order.
beforeEach(() => {
  useGameStore.getState().resetProgress();
  useGameStore.setState({ difficulty: "medium" });
});

describe("pickUp", () => {
  it("adds the item to inventory and records the object id as collected", () => {
    useGameStore.getState().pickUp("ball", "i-ball", "1");
    const s = useGameStore.getState();
    expect(s.inventory.ball).toBe(1);
    expect(s.levelProgress["1"].itemsCollected).toContain("i-ball");
  });

  it("is idempotent for the same object id (no double-counting on re-trigger)", () => {
    useGameStore.getState().pickUp("ball", "i-ball", "1");
    useGameStore.getState().pickUp("ball", "i-ball", "1");
    expect(useGameStore.getState().inventory.ball).toBe(1);
  });

  it("keeps separate levels' progress independent", () => {
    useGameStore.getState().pickUp("mouse", "m1", "2");
    const s = useGameStore.getState();
    expect(s.levelProgress["2"].itemsCollected).toEqual(["m1"]);
    expect(s.levelProgress["1"]).toBeUndefined();
  });
});

describe("completeLevel", () => {
  it("marks the level completed and unlocks the next one", () => {
    useGameStore.getState().completeLevel("1", "2");
    const s = useGameStore.getState();
    expect(s.levelProgress["1"].completed).toBe(true);
    expect(s.unlockedLevels).toContain("2");
  });

  it("does not duplicate an already-unlocked level", () => {
    useGameStore.getState().completeLevel("1", "2");
    useGameStore.getState().completeLevel("1", "2");
    const unlocked = useGameStore.getState().unlockedLevels.filter((id) => id === "2");
    expect(unlocked.length).toBe(1);
  });

  it("records a best time from levelStartedAt and clears the running timer", () => {
    useGameStore.setState({ levelStartedAt: Date.now() - 5000 });
    useGameStore.getState().completeLevel("1", "2");
    const s = useGameStore.getState();
    expect(s.bestLevelTimes["1"]).toBeGreaterThanOrEqual(5000);
    expect(s.levelStartedAt).toBeNull();
  });

  it("keeps the faster of two completion times as the best", () => {
    useGameStore.setState({ bestLevelTimes: { "1": 10_000 } });
    useGameStore.setState({ levelStartedAt: Date.now() - 3000 });
    useGameStore.getState().completeLevel("1", "2");
    expect(useGameStore.getState().bestLevelTimes["1"]).toBeLessThan(10_000);
  });

  it("does not overwrite the best time with a slower run", () => {
    useGameStore.setState({ bestLevelTimes: { "1": 1000 } });
    useGameStore.setState({ levelStartedAt: Date.now() - 9000 });
    useGameStore.getState().completeLevel("1", "2");
    expect(useGameStore.getState().bestLevelTimes["1"]).toBe(1000);
  });
});

describe("setDifficulty", () => {
  it("resets energy to the new difficulty's starting value", () => {
    useGameStore.getState().setDifficulty("hard");
    expect(useGameStore.getState().energy).toBe(DIFFICULTIES.hard.startEnergy);
  });

  it("clears any in-progress resume save (difficulty affects energy math mid-level)", () => {
    useGameStore.setState({
      save: {
        levelId: "1",
        pos: { x: 0, y: 0 },
        energy: 50,
        difficulty: "medium",
        savedAt: Date.now(),
      },
    });
    useGameStore.getState().setDifficulty("easy");
    expect(useGameStore.getState().save).toBeNull();
  });

  it("explorer difficulty never drains energy from sprinting or danger", () => {
    expect(DIFFICULTIES.explorer.sprintDrainMul).toBe(0);
    expect(DIFFICULTIES.explorer.dangerDamage).toBe(0);
  });
});

describe("drainEnergy / restoreEnergy", () => {
  it("clamps energy at 0 on the low end", () => {
    useGameStore.setState({ energy: 5 });
    useGameStore.getState().drainEnergy(20);
    expect(useGameStore.getState().energy).toBe(0);
  });

  it("clamps energy at MAX_ENERGY on the high end", () => {
    useGameStore.setState({ energy: 95 });
    useGameStore.getState().restoreEnergy(20);
    expect(useGameStore.getState().energy).toBe(100);
  });
});
