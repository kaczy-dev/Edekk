import { useCallback, useEffect, useRef, useState } from "react";
import { useNavigate } from "@tanstack/react-router";
import type Phaser from "phaser";
import type { ItemId, LevelDef, LevelObject } from "@/game/types";
import { LEVELS } from "@/game/levels";
import type { LevelScene, LevelSceneInit } from "@/game/phaser/LevelScene";
import { useGameStore, DIFFICULTIES } from "@/store/gameStore";
import { ITEMS } from "@/game/items";
import { NPC_GIFTS, giftObjId } from "@/game/inventory";
import { HUD } from "./HUD";
import { DialogBox } from "./DialogBox";
import { Toast } from "./Toast";
import { PauseMenu } from "./PauseMenu";
import { ControlsModal } from "./ControlsModal";
import { VirtualJoystick } from "./VirtualJoystick";
import { DPad } from "./DPad";
import { GoalArrows } from "./GoalArrows";
import { audio } from "@/lib/audio";
import edekSprite from "@/assets/edek-sprite.png";
import { AnimatePresence, motion } from "framer-motion";

interface Props {
  level: LevelDef;
}

/**
 * Phaser-backed spike of the gameplay surface, currently wired up for
 * Level 1 only (see `poziom.$id.tsx`). Mirrors `GameCanvas.tsx`'s
 * React<->engine bridge but drives a `LevelScene` instead of the
 * hand-rolled Canvas2D `GameEngine`.
 */
export function PhaserGameCanvas({ level }: Props) {
  const wrapRef = useRef<HTMLDivElement>(null);
  const gameRef = useRef<Phaser.Game | null>(null);
  const sceneRef = useRef<LevelScene | null>(null);
  const navigate = useNavigate();

  // Levels already cleared skip the narrated intro — see GameCanvas.tsx for
  // the identical rationale (kept in sync between the two engines).
  const [dialog, setDialog] = useState<string | null>(() =>
    useGameStore.getState().levelProgress[level.id]?.completed ? null : level.intro,
  );
  const [toast, setToast] = useState<string | null>(null);
  const [paused, setPaused] = useState(false);
  const [nearby, setNearby] = useState<LevelObject | null>(null);
  const [sprinting, setSprinting] = useState(false);
  const [showHintModal, setShowHintModal] = useState(false);
  const toastTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const controls = useGameStore((s) => s.controls);
  const difficulty = useGameStore((s) => s.difficulty);
  const startLevel = useGameStore((s) => s.startLevel);
  const pickUp = useGameStore((s) => s.pickUp);
  const markTalked = useGameStore((s) => s.markTalked);
  const drain = useGameStore((s) => s.drainEnergy);
  const restore = useGameStore((s) => s.restoreEnergy);
  const completeLevel = useGameStore((s) => s.completeLevel);
  const clearSave = useGameStore((s) => s.clearSave);
  const storeSave = useGameStore((s) => s.setSave);

  useEffect(() => {
    const saved = useGameStore.getState().save;
    const resuming = saved?.levelId === level.id;
    startLevel(level.id, { resume: resuming });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [level.id]);

  useEffect(() => {
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = prev;
    };
  }, []);

  const prevDialogRef = useRef<string | null>(null);
  useEffect(() => {
    const scene = sceneRef.current;
    if (scene) {
      scene.paused = paused || !!dialog;
      // A fresh dialog opening gets a subtle zoom-in — a small nudge toward
      // the "cinematic" framing the cozy tone calls for, not a hard cut.
      if (dialog && !prevDialogRef.current) scene.pulseZoom(1.06, 260);
    }
    prevDialogRef.current = dialog;
  }, [paused, dialog]);

  useEffect(() => {
    if (sceneRef.current) sceneRef.current.difficulty = difficulty;
  }, [difficulty]);

  useEffect(() => {
    if (sceneRef.current) sceneRef.current.sprintMode = controls.sprintMode;
  }, [controls.sprintMode]);

  useEffect(() => {
    const unsub = useGameStore.subscribe((s) => {
      if (sceneRef.current) sceneRef.current.energy = s.energy;
    });
    return unsub;
  }, []);

  // Navigate to next level when dialog closes after goal completion.
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
    const wrap = wrapRef.current;
    if (!wrap) return;
    let cancelled = false;
    let game: Phaser.Game | null = null;
    let saveTimer: ReturnType<typeof setInterval> | null = null;

    let energyAcc = 0;
    const events = {
      onNearby: (obj: LevelObject | null) => setNearby(obj),
      onPickUp: (obj: LevelObject) => {
        if (!obj.itemId) return;
        pickUp(obj.itemId, obj.id, level.id);
        audio.playPickup(useGameStore.getState().muted ? 0 : useGameStore.getState().volume);
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
        audio.playCompletion(useGameStore.getState().muted ? 0 : useGameStore.getState().volume);
        setDialog(obj.message ?? "Cel osiągnięty!");
      },
      onDanger: (obj: LevelObject) => {
        const state = useGameStore.getState();
        drain(DIFFICULTIES[state.difficulty].dangerDamage);
        if (controls.vibration && "vibrate" in navigator) navigator.vibrate?.(80);
        audio.playDanger(state.muted ? 0 : state.volume);
        setDialog(obj.message ?? "Uważaj!");
      },
      onEnergyDelta: (delta: number) => {
        energyAcc += delta;
        if (Math.abs(energyAcc) >= 1) {
          const whole = Math.trunc(energyAcc);
          energyAcc -= whole;
          if (whole > 0) restore(whole);
          else drain(-whole);
          if (sceneRef.current) sceneRef.current.energy = useGameStore.getState().energy;
        }
      },
      onSprintState: (s: boolean) => setSprinting(s),
      onHop: () => useGameStore.getState().recordHop(),
      onDistance: (px: number) => useGameStore.getState().addDistance(px),
    };

    const saved = useGameStore.getState().save;
    const collected = useGameStore.getState().levelProgress[level.id]?.itemsCollected ?? [];
    const initialPos = saved && saved.levelId === level.id ? saved.pos : undefined;

    // Phaser touches `window` at import time, which breaks TanStack Start's
    // SSR render pass. Load it (and the scene, which imports it) only after
    // this client-only effect has mounted.
    (async () => {
      const [{ default: PhaserLib }, { LevelScene }] = await Promise.all([
        import("phaser"),
        import("@/game/phaser/LevelScene"),
      ]);
      if (cancelled) return;

      const sceneInit: LevelSceneInit = {
        level,
        catSpriteUrl: edekSprite,
        events,
        collected,
        initialPos,
        initialEnergy: useGameStore.getState().energy,
        difficulty: useGameStore.getState().difficulty,
        onReady: (scene) => {
          if (cancelled) return;
          sceneRef.current = scene;
          scene.paused = paused || !!dialog;
          scene.sprintMode = useGameStore.getState().controls.sprintMode;
        },
      };

      game = new PhaserLib.Game({
        type: PhaserLib.AUTO,
        parent: wrap,
        width: wrap.clientWidth,
        height: wrap.clientHeight,
        backgroundColor: "#000000",
        physics: { default: "arcade", arcade: { debug: false } },
        scale: { mode: PhaserLib.Scale.RESIZE },
        scene: [],
      });
      gameRef.current = game;

      // `autoStart: true` (4th arg) boots the scene with `sceneInit` already
      // available to `init()`/`preload()` — adding it via the `scene:` config
      // array above would boot it with no data on the very first frame.
      // `add()` does not return the booted instance synchronously (boot is
      // deferred), so `sceneRef` is populated via `sceneInit.onReady` instead.
      game.scene.add("LevelScene", LevelScene, true, sceneInit);

      saveTimer = setInterval(() => {
        const s = sceneRef.current;
        if (!s || s.paused) return;
        storeSave({
          levelId: level.id,
          pos: { x: Math.round(s.pos.x), y: Math.round(s.pos.y) },
          energy: useGameStore.getState().energy,
          difficulty: useGameStore.getState().difficulty,
          savedAt: Date.now(),
        });
      }, 2000);
    })();

    return () => {
      cancelled = true;
      if (saveTimer) clearInterval(saveTimer);
      if (toastTimerRef.current) clearTimeout(toastTimerRef.current);
      sceneRef.current = null;
      game?.destroy(true);
      gameRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [level.id]);

  const getCatPos = useCallback(() => sceneRef.current?.pos ?? null, []);
  const getCamera = useCallback(
    () =>
      sceneRef.current
        ? { x: sceneRef.current.cam.x, y: sceneRef.current.cam.y, zoom: sceneRef.current.zoom }
        : null,
    [],
  );

  const restart = () => {
    setPaused(false);
    setDialog(level.intro);
    navigate({ to: "/poziom/$id", params: { id: level.id }, replace: true });
  };

  const triggerInteract = () => {
    if (sceneRef.current) sceneRef.current.interactPressed = true;
  };

  const joySide = controls.joystickSide;
  const actionSide = joySide === "left" ? "right" : "left";

  return (
    <div ref={wrapRef} className="relative h-[100dvh] w-full overflow-hidden bg-black select-none">
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
      {/* No HTML "Porozmawiaj/Wejdź" chip here (unlike GameCanvas.tsx) — the
          Phaser scene already renders an in-world 💬/🚪 cue above the cat's
          head (LevelScene.ts's `interactIcon`), so the two would otherwise
          always show at once and say the same thing twice. */}

      <DialogBox text={dialog} onClose={() => setDialog(null)} />
      <Toast text={toast} />
      <PauseMenu open={paused} onResume={() => setPaused(false)} onRestart={restart} level={level} />
      <ControlsModal
        open={showHintModal}
        onClose={() => setShowHintModal(false)}
        difficulty={difficulty}
        sprintMode={controls.sprintMode}
      />

      {controls.touchControl === "dpad" ? (
        <DPad
          side={joySide}
          onChange={(v) => {
            if (sceneRef.current) sceneRef.current.touch = v ?? { x: 0, y: 0 };
          }}
        />
      ) : (
        <VirtualJoystick
          side={joySide}
          onChange={(v) => {
            if (sceneRef.current) sceneRef.current.touch = v ?? { x: 0, y: 0 };
          }}
          onSprintToggle={(active) => {
            if (!sceneRef.current) return;
            if (controls.sprintMode === "toggle") sceneRef.current.sprintToggled = active;
            else sceneRef.current.touchSprint = active;
          }}
        />
      )}

      <button
        onPointerDown={() => {
          if (!sceneRef.current) return;
          if (controls.sprintMode === "toggle")
            sceneRef.current.sprintToggled = !sceneRef.current.sprintToggled;
          else sceneRef.current.touchSprint = true;
        }}
        onPointerUp={() => {
          if (sceneRef.current && controls.sprintMode === "hold")
            sceneRef.current.touchSprint = false;
        }}
        onPointerCancel={() => {
          if (sceneRef.current && controls.sprintMode === "hold")
            sceneRef.current.touchSprint = false;
        }}
        className={[
          "pointer-events-auto fixed bottom-32 z-40 grid h-14 w-14 place-items-center rounded-full border text-xs font-bold shadow-xl backdrop-blur-md active:scale-95 md:hidden transition",
          actionSide === "right" ? "right-8" : "left-8",
          sprinting
            ? "border-honey bg-honey/30 text-honey"
            : "border-white/20 bg-black/45 text-honey",
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
