export type Vec2 = { x: number; y: number };
export type Rect = { x: number; y: number; w: number; h: number };

export type ItemId =
  | "bowl" | "ball" | "mouse" | "treat" | "key" | "chest" | "yarn" | "star";

export type ItemDef = {
  id: ItemId;
  name: string;
  emoji: string;
  description: string;
};

export type LevelObjectKind = "obstacle" | "item" | "npc" | "goal" | "trigger";

export interface LevelObject {
  id: string;
  kind: LevelObjectKind;
  rect: Rect;
  itemId?: ItemId;
  npcId?: string;
  message?: string;
  /** how many of which items must be collected to complete this goal */
  requires?: Partial<Record<ItemId, number>>;
  collected?: boolean;
  /** for danger triggers in garden */
  danger?: boolean;
}

export type QuestStep =
  | { id: string; kind: "collect"; itemId: ItemId; count: number; label: string }
  | { id: string; kind: "talk"; objId: string; label: string }
  | { id: string; kind: "reach"; objId: string; label: string };

export interface LevelDef {
  id: string;
  slug: string;
  title: string;
  subtitle: string;
  background: string;
  /** virtual world size in px */
  width: number;
  height: number;
  spawn: Vec2;
  ambient?: "day" | "dim" | "night";
  /** dialog spoken by Edek's narrator at start */
  intro: string;
  /** final objective text */
  objective: string;
  /** short reason why this level was locked (shown in menu) */
  unlockHint: string;
  /** structured checklist of tasks shown in HUD and journal */
  quests: QuestStep[];
  objects: LevelObject[];
}

