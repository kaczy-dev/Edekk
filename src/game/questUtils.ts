import type { LevelDef, QuestStep, ItemId } from "./types";

export interface QuestStatus {
  quest: QuestStep;
  done: boolean;
  current: number;
  total: number;
  /** For reach quests: requirements met but goal not yet reached. */
  ready?: boolean;
}

interface Snapshot {
  inventory: Partial<Record<ItemId, number>>;
  talked: string[];
  levelCompleted: boolean;
}

export function computeQuests(level: LevelDef, s: Snapshot): QuestStatus[] {
  return level.quests.map((q) => {
    if (q.kind === "collect") {
      const have = Math.min(q.count, s.inventory[q.itemId] ?? 0);
      return { quest: q, done: have >= q.count, current: have, total: q.count };
    }
    if (q.kind === "talk") {
      const done = s.talked.includes(q.objId);
      return { quest: q, done, current: done ? 1 : 0, total: 1 };
    }
    // reach — done only after the engine confirms the goal.
    // "ready" if the goal object's `requires` are already satisfied.
    const goal = level.objects.find((o) => o.id === q.objId);
    let ready = true;
    if (goal?.requires) {
      for (const [k, n] of Object.entries(goal.requires)) {
        if ((s.inventory[k as ItemId] ?? 0) < (n ?? 0)) { ready = false; break; }
      }
    }
    return {
      quest: q,
      done: s.levelCompleted,
      current: s.levelCompleted ? 1 : 0,
      total: 1,
      ready: !s.levelCompleted && ready,
    };
  });
}

export function questCompletion(statuses: QuestStatus[]) {
  const done = statuses.filter((s) => s.done).length;
  return { done, total: statuses.length };
}

