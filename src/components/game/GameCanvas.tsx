import { useCallback, useEffect, useRef, useState } from "react";
import { useNavigate } from "@tanstack/react-router";
import { GameEngine } from "@/game/engine";
import type { ItemId, LevelDef, LevelObject } from "@/game/types";
import { LEVELS } from "@/game/levels";
import { useGameStore, DIFFICULTIES } from "@/store/gameStore";
import { ITEMS } from "@/game/items";
import { NPC_GIFTS, giftObjId } from "@/game/inventory";
import { HUD } from "./HUD";
import { DialogBox } from "./DialogBox";
import { Toast } from "./Toast";
import { ControlsModal } from "./ControlsModal";
import { PauseMenu } from "./PauseMenu";
import { VirtualJoystick } from "./VirtualJoystick";
import { DPad } from "./DPad";
import { GoalArrows } from "./GoalArrows";
import edekSprite from "@/assets/edek-topdown.png";
import { AnimatePresence, motion } from "framer-motion";

interface Props {
  level: LevelDef;
}

export function GameCanvas({ level }: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const wrapRef = useRef<HTMLDivElement>(null);
  const engineRef = useRef<GameEngine | null>(null);
  const navigate = useNavigate();

  const [dialog, setDialog] = useState<string | null>(level.intro);
  const [toast, setToast] = useState<string | null>(null);
  const [paused, setPaused] = useState(false);
  const [nearby, setNearby] = useState<LevelObject | null>(null);
  const [sprinting, setSprinting] = useState(false);
  const toastTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const controls = useGameStore((s) => s.controls);
  const difficulty = useGameStore((s) => s.difficulty);
  const showHintsPref = controls.showHints;
  const [showHint, setShowHint] = useState(showHintsPref);
  const [showHintModal, setShowHintModal] = useState(false);

  useEffect(() => {
    if (!showHintsPref) { setShowHint(false); return; }
    setShowHint(true);
    const t = setTimeout(() => setShowHint(false), 6000);
    return () => clearTimeout(t);
  }, [level.id, showHintsPref]);

  const startLevel = useGameStore((s) => s.startLevel);
  const pickUp = useGameStore((s) => s.pickUp);
  const markTalked = useGameStore((s) => s.markTalked);
  const drain = useGameStore((s) => s.drainEnergy);
  const restore = useGameStore((s) => s.restoreEnergy);
  const completeLevel = useGameStore((s) => s.completeLevel);
  const setSave = useGameStore((s) => s.setSave);
  const clearSave = useGameStore((s) => s.clearSave);

  useEffect(() => {
    const saved = useGameStore.getState().save;
    const resuming = saved?.levelId === level.id;
    if (resuming && saved && saved.difficulty !== useGameStore.getState().difficulty) {
      // Restore difficulty from save WITHOUT invalidating the save slot.
      useGameStore.setState({ difficulty: saved.difficulty });
    }
    startLevel(level.id, { resume: resuming });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [level.id]);

  // The level is a fixed full-viewport surface; stop the page itself scrolling or
  // rubber-banding under trackpad and touch gestures while playing.
  useEffect(() => {
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = prev;
    };
  }, []);

  useEffect(() => {
    if (engineRef.current) engineRef.current.paused = paused || !!dialog;
  }, [paused, dialog]);

  // push control settings into engine when they change
  useEffect(() => {
    if (engineRef.current) engineRef.current.input.setSettings(controls);
  }, [controls]);

  // Navigate to next level when dialog closes after goal completion
  useEffect(() => {
    if (dialog === null) {
      const state = useGameStore.getState();
      const idx = LEVELS.findIndex((l) => l.id === level.id);
      const isCompleted = state.levelProgress[level.id]?.completed ?? false;
      if (isCompleted) {
        const next = LEVELS[idx + 1];
        setTimeout(() => {
          if (next) navigate({ to: "/poziom/$id", params: { id: next.id } });
          else navigate({ to: "/koniec" });
        }, 300);
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dialog]);

  useEffect(() => {
    if (engineRef.current) engineRef.current.difficulty = difficulty;
  }, [difficulty]);

  // keep engine.energy in sync with the store (for sprint gating)
  useEffect(() => {
    const unsub = useGameStore.subscribe((s) => {
      if (engineRef.current) engineRef.current.energy = s.energy;
    });
    return unsub;
  }, []);

  useEffect(() => {
    const canvas = canvasRef.current;
    const wrap = wrapRef.current;
    if (!canvas || !wrap) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const resize = () => {
      const dpr = window.devicePixelRatio || 1;
      const w = wrap.clientWidth;
      const h = wrap.clientHeight;
      canvas.width = w * dpr;
      canvas.height = h * dpr;
      canvas.style.width = w + "px";
      canvas.style.height = h + "px";
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.imageSmoothingEnabled = true;
      // Per-frame default; the engine bumps quality only where it bakes caches.
      ctx.imageSmoothingQuality = "low";
    };
    resize();
    window.addEventListener("resize", resize);

    const catImg = new Image();
    catImg.src = edekSprite;
    const bgImg = new Image();
    bgImg.src = level.background;

    let energyAcc = 0; // fractional energy delta accumulator
    const events = {
      onMove: () => {},
      onNearby: (obj: LevelObject | null) => setNearby(obj),
      onPickUp: (obj: LevelObject) => {
        if (!obj.itemId) return;
        pickUp(obj.itemId, obj.id, level.id);
        if (toastTimerRef.current) clearTimeout(toastTimerRef.current);
        setToast(`${ITEMS[obj.itemId].emoji}  ${ITEMS[obj.itemId].name}`);
        toastTimerRef.current = setTimeout(() => setToast(null), 1500);
      },
      onTalk: (obj: LevelObject) => {
        setDialog(obj.message ?? "...");
        markTalked(level.id, obj.id);
        const gift = obj.npcId ? NPC_GIFTS[obj.npcId] : undefined;
        if (gift && !useGameStore.getState().inventory[gift]) {
          pickUp(gift, giftObjId(obj.id), level.id);
        }
      },
      onGoal: (obj: LevelObject) => {
        const inv = useGameStore.getState().inventory;
        if (obj.requires) {
          const requirements = Object.entries(obj.requires) as [ItemId, number][];
          if (requirements.some(([id, need]) => (inv[id] ?? 0) < need)) {
            const missing = requirements
              .map(([id, need]) => `${ITEMS[id]?.emoji ?? "❓"} ${inv[id] ?? 0}/${need}`)
              .join("   ");
            setDialog(`Jeszcze nie wszystko. Potrzeba:  ${missing}`);
            return;
          }
        }
        const idx = LEVELS.findIndex((l) => l.id === level.id);
        const next = LEVELS[idx + 1];
        completeLevel(level.id, next?.id);
        clearSave();
        setDialog(obj.message ?? "Cel osiągnięty!");
        // Navigation happens in a useEffect watching for dialog close + completion
      },
      onDanger: (obj: LevelObject) => {
        drain(DIFFICULTIES[useGameStore.getState().difficulty].dangerDamage);
        if (controls.vibration && "vibrate" in navigator) navigator.vibrate?.(80);
        setDialog(obj.message ?? "Uważaj!");
      },
      onEnergyDelta: (delta: number) => {
        energyAcc += delta;
        if (Math.abs(energyAcc) >= 1) {
          const whole = Math.trunc(energyAcc);
          energyAcc -= whole;
          if (whole > 0) restore(whole); else drain(-whole);
          if (engineRef.current) engineRef.current.energy = useGameStore.getState().energy;
        }
      },
      onSprintState: (s: boolean) => setSprinting(s),
    };

    let started = false;
    // Set on cleanup: without it a late image `load` would start an engine for an
    // already-unmounted effect, orphaning a RAF loop and an autosave interval that
    // nothing can cancel. Repeated mounts (HMR, level changes) stack them up.
    let cancelled = false;
    let saveTimer: ReturnType<typeof setInterval> | null = null;
    const tryStart = () => {
      if (cancelled || started || !catImg.complete || !bgImg.complete) return;
      started = true;
      const engine = new GameEngine(level, catImg, bgImg, events);
      engine.input.setSettings(useGameStore.getState().controls);
      engine.difficulty = useGameStore.getState().difficulty;
      engine.energy = useGameStore.getState().energy;
      const collected = useGameStore.getState().levelProgress[level.id]?.itemsCollected ?? [];
      engine.markCollected(collected);

      // Resume saved position if it matches this level.
      const saved = useGameStore.getState().save;
      if (saved && saved.levelId === level.id) {
        engine.pos = { x: saved.pos.x, y: saved.pos.y };
      }

      engineRef.current = engine;
      engine.start(ctx);

      // Autosave every 2s while in-level.
      saveTimer = setInterval(() => {
        const e = engineRef.current;
        if (!e || e.paused) return;
        setSave({
          levelId: level.id,
          pos: { x: Math.round(e.pos.x), y: Math.round(e.pos.y) },
          energy: useGameStore.getState().energy,
          difficulty: useGameStore.getState().difficulty,
          savedAt: Date.now(),
        });
      }, 2000);
    };
    catImg.onload = tryStart;
    bgImg.onload = tryStart;
    tryStart();

    const onHide = () => {
      const e = engineRef.current;
      if (!e) return;
      setSave({
        levelId: level.id,
        pos: { x: Math.round(e.pos.x), y: Math.round(e.pos.y) },
        energy: useGameStore.getState().energy,
        difficulty: useGameStore.getState().difficulty,
        savedAt: Date.now(),
      });
    };
    window.addEventListener("pagehide", onHide);
    document.addEventListener("visibilitychange", onHide);

    return () => {
      cancelled = true;
      catImg.onload = null;
      bgImg.onload = null;
      window.removeEventListener("resize", resize);
      window.removeEventListener("pagehide", onHide);
      document.removeEventListener("visibilitychange", onHide);
      if (saveTimer) clearInterval(saveTimer);
      onHide();
      engineRef.current?.stop();
      engineRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [level.id]);

  // Stable identities: the HUD and arrow trackers key their animation loops off these.
  const getCatPos = useCallback(() => engineRef.current?.pos ?? null, []);
  const getCamera = useCallback(
    () =>
      engineRef.current
        ? { x: engineRef.current.cam.x, y: engineRef.current.cam.y, zoom: engineRef.current.zoom }
        : null,
    []
  );

  const restart = () => {
    setPaused(false);
    setDialog(level.intro);
    navigate({ to: "/poziom/$id", params: { id: level.id }, replace: true });
  };

  const triggerInteract = () => {
    if (engineRef.current) engineRef.current.input.interactPressed = true;
  };

  const nearbyLabel = nearby
    ? nearby.kind === "npc"
      ? "Porozmawiaj"
      : "Wejdź"
    : null;

  const joySide = controls.joystickSide;
  const actionSide = joySide === "left" ? "right" : "left";

  return (
    <div ref={wrapRef} className="relative h-[100dvh] w-full overflow-hidden bg-black select-none">
      <canvas ref={canvasRef} className="block h-full w-full" />
      <HUD
        level={level}
        onPause={() => setPaused(true)}
        sprinting={sprinting}
        getCatPos={getCatPos}
        onShowControls={() => setShowHintModal(true)}
      />
      <GoalArrows
        level={level}
        getCatPos={getCatPos}
        getCamera={getCamera}
        containerRef={wrapRef}
      />

      <AnimatePresence>
        {nearbyLabel && !dialog && !paused && (
          <motion.div
            key={nearby?.id}
            initial={{ opacity: 0, y: 8, scale: 0.9 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 8, scale: 0.9 }}
            className="pointer-events-none absolute left-1/2 top-[18%] z-30 -translate-x-1/2 rounded-full border border-honey/40 bg-black/55 px-4 py-1.5 text-sm font-medium text-white shadow-xl backdrop-blur-md"
          >
            <kbd className="mr-2 inline-grid h-5 w-5 place-items-center rounded bg-white/15 text-[10px] font-bold text-honey">E</kbd>
            {nearbyLabel}
          </motion.div>
        )}
      </AnimatePresence>

      <DialogBox text={dialog} onClose={() => setDialog(null)} />
      <Toast text={toast} />
      <ControlsModal
        open={showHintModal}
        onClose={() => setShowHintModal(false)}
        difficulty={difficulty}
        sprintMode={controls.sprintMode}
      />

      <AnimatePresence>
        {showHint && !paused && (
          <motion.div
            initial={{ opacity: 0, y: -8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            className="pointer-events-none absolute bottom-6 left-1/2 z-30 hidden w-max max-w-[92vw] -translate-x-1/2 flex-col items-center gap-1.5 rounded-2xl border border-white/10 bg-black/50 px-4 py-2.5 text-xs text-white/85 backdrop-blur-md md:flex"
          >
            <div className="flex items-center gap-3">
              <span className="flex items-center gap-1">
                <kbd className="rounded bg-white/15 px-1.5 py-0.5 text-[10px] font-bold text-honey">WSAD</kbd>
                ruch
              </span>
              <span className="text-white/30">·</span>
              <span className="flex items-center gap-1">
                <kbd className="rounded bg-white/15 px-1.5 py-0.5 text-[10px] font-bold text-honey">Shift</kbd>
                bieg ({controls.sprintMode === "toggle" ? "przełącz" : "trzymaj"})
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
          </motion.div>
        )}
      </AnimatePresence>

      <PauseMenu open={paused} onResume={() => setPaused(false)} onRestart={restart} />

      {controls.touchControl === "dpad" ? (
        <DPad
          side={joySide}
          onChange={(v) => {
            if (engineRef.current) engineRef.current.input.touch = v;
          }}
        />
      ) : (
        <VirtualJoystick
          side={joySide}
          onChange={(v) => {
            if (engineRef.current) engineRef.current.input.touch = v;
          }}
        />
      )}

      {/* Mobile sprint + interact buttons (opposite side of joystick) */}
      <button
        onPointerDown={() => {
          if (!engineRef.current) return;
          if (controls.sprintMode === "toggle") {
            engineRef.current.input.sprintToggled = !engineRef.current.input.sprintToggled;
          } else {
            engineRef.current.input.touchSprint = true;
          }
        }}
        onPointerUp={() => {
          if (engineRef.current && controls.sprintMode === "hold") engineRef.current.input.touchSprint = false;
        }}
        onPointerCancel={() => {
          if (engineRef.current && controls.sprintMode === "hold") engineRef.current.input.touchSprint = false;
        }}
        className={[
          "pointer-events-auto fixed bottom-32 z-40 grid h-14 w-14 place-items-center rounded-full border text-xs font-bold shadow-xl backdrop-blur-md active:scale-95 md:hidden transition",
          actionSide === "right" ? "right-8" : "left-8",
          sprinting ? "border-honey bg-honey/30 text-honey" : "border-white/20 bg-black/45 text-honey",
        ].join(" ")}
        aria-label="Bieg"
      >
        BIEG
      </button>
      <button
        onPointerDown={triggerInteract}
        className={[
          "pointer-events-auto fixed bottom-10 z-40 grid h-20 w-20 place-items-center rounded-full border text-2xl font-bold shadow-2xl backdrop-blur-md transition active:scale-95 md:hidden",
          actionSide === "right" ? "right-8" : "left-8",
          nearby
            ? "border-honey bg-primary text-primary-foreground animate-pulse"
            : "border-white/15 bg-black/45 text-white/70",
        ].join(" ")}
        aria-label="Interakcja"
      >
        E
      </button>
    </div>
  );
}
