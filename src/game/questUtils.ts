import type { LevelDef, QuestStep, ItemId, LevelObject } from "./types";
import { ITEMS } from "./items";

export interface MissingHint {
  /** Short human-readable "what's missing" line. */
  label: string;
  /** Where to find it: location or NPC hint. */
  where: string;
  /** Optional emoji for visual scan. */
  emoji?: string;
}

export interface QuestStatus {
  quest: QuestStep;
  done: boolean;
  current: number;
  total: number;
  /** For reach quests: requirements met but goal not yet reached. */
  ready?: boolean;
  /** Actionable hints about what's still missing and where to find it. */
  missing: MissingHint[];
}

interface Snapshot {
  inventory: Partial<Record<ItemId, number>>;
  talked: string[];
  levelCompleted: boolean;
  /** ids of level objects already picked up / consumed */
  collected: string[];
}

/** Items that don't spawn on the map — where to acquire them. */
const ITEM_SOURCE_FALLBACK: Partial<Record<ItemId, { where: string; levelHint?: string }>> = {
  yarn: { where: "Prezent od wiewiórki w Ogrodzie (porozmawiaj z nią)." },
  treat: { where: "Nagroda za wypełnienie zadań pobocznych." },
  chest: { where: "Otwierana kluczem na Strychu." },
};

function locationOf(obj: LevelObject, level: LevelDef): string {
  const cx = obj.rect.x + obj.rect.w / 2;
  const cy = obj.rect.y + obj.rect.h / 2;
  const fx = cx / level.width;
  const fy = cy / level.height;
  const h = fx < 0.34 ? "po lewej" : fx > 0.66 ? "po prawej" : "na środku";
  const v = fy < 0.34 ? "u góry" : fy > 0.66 ? "na dole" : "w środkowym pasie";
  return `${v} mapy, ${h}`;
}

function missingItems(
  itemId: ItemId,
  need: number,
  have: number,
  level: LevelDef,
  collected: string[]
): MissingHint[] {
  const def = ITEMS[itemId];
  const remaining = Math.max(0, need - have);
  if (remaining <= 0) return [];

  const sources = level.objects.filter(
    (o) => o.kind === "item" && o.itemId === itemId && !collected.includes(o.id)
  );

  const hints: MissingHint[] = [];
  if (sources.length > 0) {
    // List up to `remaining` sources with location descriptors.
    const slice = sources.slice(0, remaining);
    slice.forEach((src, i) => {
      hints.push({
        emoji: def.emoji,
        label:
          remaining > 1
            ? `${def.name} (${i + 1}/${remaining} brakująca)`
            : `${def.name} — brakuje 1 szt.`,
        where: locationOf(src, level),
      });
    });
    // If more remaining than sources on this map, note the shortfall.
    if (sources.length < remaining) {
      hints.push({
        emoji: "❓",
        label: `${def.name} — ${remaining - sources.length} poza tą planszą`,
        where:
          ITEM_SOURCE_FALLBACK[itemId]?.where ??
          "Sprawdź poprzednie plansze — mogłeś coś pominąć.",
      });
    }
  } else {
    hints.push({
      emoji: def.emoji,
      label: `${def.name} — brakuje ${remaining}`,
      where:
        ITEM_SOURCE_FALLBACK[itemId]?.where ??
        "Brak na tej planszy — wróć do wcześniejszych poziomów.",
    });
  }
  return hints;
}

export function computeQuests(level: LevelDef, s: Snapshot): QuestStatus[] {
  return level.quests.map((q) => {
    if (q.kind === "collect") {
      const have = Math.min(q.count, s.inventory[q.itemId] ?? 0);
      const done = have >= q.count;
      return {
        quest: q,
        done,
        current: have,
        total: q.count,
        missing: done ? [] : missingItems(q.itemId, q.count, have, level, s.collected),
      };
    }

    if (q.kind === "talk") {
      const done = s.talked.includes(q.objId);
      const npc = level.objects.find((o) => o.id === q.objId);
      return {
        quest: q,
        done,
        current: done ? 1 : 0,
        total: 1,
        missing: done || !npc
          ? []
          : [{
              emoji: "💬",
              label: "Podejdź i naciśnij E, aby porozmawiać.",
              where: locationOf(npc, level),
            }],
      };
    }

    // reach
    const goal = level.objects.find((o) => o.id === q.objId);
    const missing: MissingHint[] = [];
    let ready = true;
    if (goal?.requires) {
      for (const [k, n] of Object.entries(goal.requires)) {
        const itemId = k as ItemId;
        const need = n ?? 0;
        const have = s.inventory[itemId] ?? 0;
        if (have < need) {
          ready = false;
          missing.push(...missingItems(itemId, need, have, level, s.collected));
        }
      }
    }
    const done = s.levelCompleted;
    if (!done && ready && goal) {
      missing.push({
        emoji: "🚩",
        label: "Warunki spełnione — dotrzyj do celu.",
        where: locationOf(goal, level),
      });
    }
    return {
      quest: q,
      done,
      current: done ? 1 : 0,
      total: 1,
      ready: !done && ready,
      missing: done ? [] : missing,
    };
  });
}

export function questCompletion(statuses: QuestStatus[]) {
  const done = statuses.filter((s) => s.done).length;
  return { done, total: statuses.length };
}
