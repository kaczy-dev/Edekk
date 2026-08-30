import type { ItemId, LevelDef } from "./types";

/**
 * Items granted by an NPC when talked to, keyed by npcId. Gifts are recorded in
 * `levelProgress.itemsCollected` under a synthetic id (the NPC object's id plus
 * GIFT_SUFFIX) because they have no pickup object on the map.
 */
export const NPC_GIFTS: Record<string, ItemId> = {
  squirrel: "yarn",
  pigeon: "feather",
};

const GIFT_SUFFIX = "-gift";

export const giftObjId = (npcObjId: string) => `${npcObjId}${GIFT_SUFFIX}`;

function collectedItemId(level: LevelDef, objId: string): ItemId | undefined {
  if (objId.endsWith(GIFT_SUFFIX)) {
    const npcId = objId.slice(0, -GIFT_SUFFIX.length);
    const npc = level.objects.find((o) => o.id === npcId);
    return npc?.npcId ? NPC_GIFTS[npc.npcId] : undefined;
  }
  const obj = level.objects.find((o) => o.id === objId);
  return obj?.kind === "item" ? obj.itemId : undefined;
}

/** Rebuild a level-run inventory from the object ids recorded as collected. */
export function inventoryFromCollected(
  level: LevelDef,
  collectedIds: string[]
): Partial<Record<ItemId, number>> {
  const inventory: Partial<Record<ItemId, number>> = {};
  for (const objId of collectedIds) {
    const itemId = collectedItemId(level, objId);
    if (itemId) inventory[itemId] = (inventory[itemId] ?? 0) + 1;
  }
  return inventory;
}
