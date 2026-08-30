import { motion, AnimatePresence } from "framer-motion";
import { DIFFICULTIES } from "@/store/gameStore";
import type { Difficulty } from "@/store/gameStore";

interface Props {
  difficulty: Difficulty;
  sprintMode: "hold" | "toggle";
  inline?: boolean;
}

export function ControlsHint({ difficulty, sprintMode, inline }: Props) {
  return (
    <div className={inline ? "space-y-3" : "flex flex-col gap-4"}>
      <div className="flex items-center gap-3">
        <span className="flex items-center gap-1">
          <kbd className="rounded bg-white/15 px-1.5 py-0.5 text-[10px] font-bold text-honey">WSAD</kbd>
          ruch
        </span>
        <span className="text-white/30">·</span>
        <span className="flex items-center gap-1">
          <kbd className="rounded bg-white/15 px-1.5 py-0.5 text-[10px] font-bold text-honey">Shift</kbd>
          bieg ({sprintMode === "toggle" ? "przełącz" : "trzymaj"})
        </span>
        <span className="text-white/30">·</span>
        <span className="flex items-center gap-1">
          <kbd className="rounded bg-white/15 px-1.5 py-0.5 text-[10px] font-bold text-honey">E</kbd>
          interakcja
        </span>
      </div>
      <div className="flex items-center gap-3 text-[11px] text-white/70">
        <span>
          <span className="text-honey">{DIFFICULTIES[difficulty].label}</span>
          {" · start "}
          <span className="tabular-nums text-white/90">{DIFFICULTIES[difficulty].startEnergy}⚡</span>
        </span>
        <span className="text-white/30">·</span>
        <span>
          bieg ×{DIFFICULTIES[difficulty].sprintDrainMul.toFixed(2)} energii
          {" (min "}
          <span className="tabular-nums text-white/90">{DIFFICULTIES[difficulty].minSprintEnergy}⚡</span>
          {")"}
        </span>
        <span className="text-white/30">·</span>
        <span>
          pszczoła −
          <span className="tabular-nums text-white/90">{DIFFICULTIES[difficulty].dangerDamage}⚡</span>
        </span>
        <span className="text-white/30">·</span>
        <span>
          odpoczynek ×{DIFFICULTIES[difficulty].restRecoverMul.toFixed(2)}
        </span>
      </div>
    </div>
  );
}
