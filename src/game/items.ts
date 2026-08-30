import type { ItemDef, ItemId } from "./types";

export const ITEMS: Record<ItemId, ItemDef> = {
  bowl: { id: "bowl", name: "Miska z karmą", emoji: "🥣", description: "Pełna miska chrupek." },
  ball: { id: "ball", name: "Piłeczka", emoji: "⚽", description: "Ulubiona zabawka Edka." },
  mouse: {
    id: "mouse",
    name: "Myszka",
    emoji: "🐭",
    description: "Pluszowa myszka z dzwoneczkiem.",
  },
  treat: { id: "treat", name: "Smakołyk", emoji: "🍤", description: "Suszona ryba. Mniam!" },
  key: { id: "key", name: "Klucz", emoji: "🗝️", description: "Stary, mosiężny klucz." },
  chest: { id: "chest", name: "Skrzynia", emoji: "🧰", description: "Skarb wspomnień." },
  yarn: { id: "yarn", name: "Kłębek", emoji: "🧶", description: "Dar wiewiórki." },
  star: { id: "star", name: "Gwiazda", emoji: "⭐", description: "Spadająca gwiazda." },
  feather: { id: "feather", name: "Piórko", emoji: "🪶", description: "Dar gołębia z podwórka." },
  leaf: { id: "leaf", name: "Złoty liść", emoji: "🍁", description: "Liść z alei kasztanowej." },
  photo: {
    id: "photo",
    name: "Zdjęcie z wyprawy",
    emoji: "📷",
    description:
      "Ukryty, malowniczy kadr — kolekcjonerska ciekawostka, nie jest wymagana do ukończenia poziomu.",
  },
};
