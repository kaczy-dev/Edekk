/**
 * Visual language for reach-quest distance tiers.
 *
 * Standard mode encodes distance mostly with colour. Colour-blind mode swaps in a
 * colour-safe (Okabe-Ito inspired) palette AND encodes the tier redundantly with
 * shape, outline pattern and a glyph, so distance is readable without hue.
 */
export type Tier = "far" | "mid" | "near" | "at";

export interface TierStyle {
  /** Fill colour for the arrow marker. */
  fill: string;
  /** Tailwind class for the soft glow behind the marker. */
  glow: string;
  /** Tailwind classes for the little distance chip. */
  chip: string;
  /** Plain colour for legend swatches / inline dots. */
  swatch: string;
  /** SVG path (24x24 viewBox) for the marker silhouette — differs per tier in CB mode. */
  path: string;
  /** Dash pattern on the marker outline: another non-colour cue. */
  dash?: string;
  /** Shape of the legend swatch. */
  swatchShape: "circle" | "square" | "diamond" | "triangle";
  /** Redundant glyph shown next to the distance text. */
  glyph: string;
  /** Human label. */
  label: string;
}

/** Solid arrow (default silhouette). */
const ARROW = "M12 2 L20 18 L12 14 L4 18 Z";
/** Wide, blunt arrow — reads as "far / coarse". */
const ARROW_WIDE = "M12 4 L22 20 L12 15 L2 20 Z";
/** Slim, tall arrow — reads as "closing in". */
const ARROW_SLIM = "M12 1 L18 20 L12 16 L6 20 Z";
/** Double chevron — unmistakable at a glance. */
const CHEVRON2 = "M12 1 L19 10 L12 7 L5 10 Z M12 11 L19 20 L12 17 L5 20 Z";

const NORMAL: Record<Tier, TierStyle> = {
  at: {
    fill: "#a7f3d0",
    glow: "bg-emerald-300/30",
    chip: "border-emerald-300/60 text-emerald-200",
    swatch: "#a7f3d0",
    path: ARROW,
    swatchShape: "circle",
    glyph: "",
    label: "tuż obok",
  },
  near: {
    fill: "var(--color-honey)",
    glow: "bg-honey/30",
    chip: "border-honey/60 text-honey",
    swatch: "var(--color-honey)",
    path: ARROW,
    swatchShape: "circle",
    glyph: "",
    label: "blisko",
  },
  mid: {
    fill: "#fbbf24",
    glow: "bg-amber-400/20",
    chip: "border-amber-400/50 text-amber-200",
    swatch: "#fbbf24",
    path: ARROW,
    swatchShape: "circle",
    glyph: "",
    label: "średnio",
  },
  far: {
    fill: "#fca5a5",
    glow: "bg-rose-400/15",
    chip: "border-rose-400/40 text-rose-200",
    swatch: "#fca5a5",
    path: ARROW,
    swatchShape: "circle",
    glyph: "",
    label: "daleko",
  },
};

/**
 * Colour-blind safe set: high-contrast blue → purple → orange → white ramp,
 * each tier additionally carrying a distinct silhouette, dash pattern and glyph.
 */
const COLORBLIND: Record<Tier, TierStyle> = {
  at: {
    fill: "#ffffff",
    glow: "bg-white/35",
    chip: "border-white/80 text-white",
    swatch: "#ffffff",
    path: CHEVRON2,
    swatchShape: "circle",
    glyph: "◉",
    label: "tuż obok",
  },
  near: {
    fill: "#ffb000",
    glow: "bg-[#ffb000]/30",
    chip: "border-[#ffb000] text-[#ffd27f]",
    swatch: "#ffb000",
    path: ARROW_SLIM,
    dash: "3 2",
    swatchShape: "triangle",
    glyph: "▲",
    label: "blisko",
  },
  mid: {
    fill: "#a06cff",
    glow: "bg-[#a06cff]/25",
    chip: "border-[#a06cff] text-[#d3bcff]",
    swatch: "#a06cff",
    path: ARROW,
    dash: "5 3",
    swatchShape: "diamond",
    glyph: "◆",
    label: "średnio",
  },
  far: {
    fill: "#5b9bff",
    glow: "bg-[#5b9bff]/20",
    chip: "border-[#5b9bff] text-[#bcd6ff]",
    swatch: "#5b9bff",
    path: ARROW_WIDE,
    dash: "2 3",
    swatchShape: "square",
    glyph: "■",
    label: "daleko",
  },
};

export function tierStyle(tier: Tier, colorBlind: boolean): TierStyle {
  return (colorBlind ? COLORBLIND : NORMAL)[tier];
}

export const TIER_ORDER: Tier[] = ["at", "near", "mid", "far"];
