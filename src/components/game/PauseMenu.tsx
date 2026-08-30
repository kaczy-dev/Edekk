import { motion, AnimatePresence } from "framer-motion";
import { Link, useRouter } from "@tanstack/react-router";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import type { LevelDef } from "@/game/types";
import { useGameStore } from "@/store/gameStore";

interface Props {
  open: boolean;
  onResume: () => void;
  onRestart: () => void;
  /** Optional: renders a found/missing minimap when supplied. */
  level?: LevelDef;
}

export function PauseMenu({ open, onResume, onRestart, level }: Props) {
  const router = useRouter();
  return (
    <AnimatePresence>
      {open && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="absolute inset-0 z-50 flex items-center justify-center scrim"
        >
          <motion.div
            initial={{ scale: 0.9, y: 20 }}
            animate={{ scale: 1, y: 0 }}
            exit={{ scale: 0.95, y: 10 }}
            className="w-80 panel-glass p-6 text-center shadow-2xl"
          >
            <h3 className="font-display text-3xl font-semibold text-honey">Pauza</h3>
            <p className="mt-1 text-sm text-muted-foreground">Edek czeka spokojnie.</p>

            {level && <LevelMinimap level={level} />}

            <div className="mt-5 flex flex-col gap-2">
              <button
                onClick={onResume}
                className="rounded-xl bg-primary px-4 py-2.5 font-semibold text-primary-foreground shadow-lg shadow-primary/20 transition hover:opacity-90 active:scale-95"
              >
                Wróć do gry
              </button>
              <AlertDialog>
                <AlertDialogTrigger className="rounded-xl border border-border bg-secondary px-4 py-2 text-sm font-medium text-secondary-foreground transition hover:bg-muted active:scale-95">
                  Zacznij poziom od nowa
                </AlertDialogTrigger>
                <AlertDialogContent>
                  <AlertDialogHeader>
                    <AlertDialogTitle>Zacząć od nowa?</AlertDialogTitle>
                    <AlertDialogDescription>Stracisz postęp w tym poziomie.</AlertDialogDescription>
                  </AlertDialogHeader>
                  <AlertDialogFooter>
                    <AlertDialogCancel>Anuluj</AlertDialogCancel>
                    <AlertDialogAction onClick={onRestart}>Tak, zacznij od nowa</AlertDialogAction>
                  </AlertDialogFooter>
                </AlertDialogContent>
              </AlertDialog>
              <AlertDialog>
                <AlertDialogTrigger className="rounded-xl px-4 py-2 text-sm text-muted-foreground transition hover:text-foreground active:scale-95 w-full text-left">
                  Wyjdź do menu
                </AlertDialogTrigger>
                <AlertDialogContent>
                  <AlertDialogHeader>
                    <AlertDialogTitle>Wyjść do menu?</AlertDialogTitle>
                    <AlertDialogDescription>Postęp w tym poziomie nie zostanie zapisany.</AlertDialogDescription>
                  </AlertDialogHeader>
                  <AlertDialogFooter>
                    <AlertDialogCancel>Anuluj</AlertDialogCancel>
                    <AlertDialogAction onClick={() => router.navigate({ to: "/menu" })}>
                      Wyjdź do menu
                    </AlertDialogAction>
                  </AlertDialogFooter>
                </AlertDialogContent>
              </AlertDialog>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

/**
 * A compact top-down dot map: obstacles as faint blocks for orientation,
 * items/npc/goal as dots — filled honey once found, hollow grey while
 * missing. Pure read of `level.objects` + the store's collected-ids list,
 * no new data model needed.
 */
function LevelMinimap({ level }: { level: LevelDef }) {
  const collected = useGameStore((s) => s.levelProgress[level.id]?.itemsCollected ?? []);
  const talked = useGameStore((s) => s.talkedNpcs[level.id] ?? []);
  const W = 240;
  const H = (level.height / level.width) * W;
  const sx = W / level.width; // uniform scale — same factor for x and y since H is derived from the same aspect ratio

  const found = level.objects.filter((o) => o.kind === "item" && collected.includes(o.id)).length;
  const totalItems = level.objects.filter((o) => o.kind === "item").length;

  return (
    <div className="mt-4">
      <div className="mb-1.5 flex items-center justify-between text-[10px] uppercase tracking-widest text-muted-foreground">
        <span>Mapa poziomu</span>
        {totalItems > 0 && <span>{found}/{totalItems} znalezione</span>}
      </div>
      <svg
        viewBox={`0 0 ${W} ${H}`}
        className="w-full rounded-xl border border-border bg-black/30"
        style={{ aspectRatio: `${level.width} / ${level.height}` }}
      >
        {level.objects
          .filter((o) => o.kind === "obstacle")
          .map((o) => (
            <rect
              key={o.id}
              x={o.rect.x * sx}
              y={o.rect.y * sx}
              width={o.rect.w * sx}
              height={o.rect.h * sx}
              className="fill-white/10"
            />
          ))}
        {level.objects
          .filter((o) => o.kind !== "obstacle")
          .map((o) => {
            const isFound =
              o.kind === "item" ? collected.includes(o.id) : o.kind === "npc" ? talked.includes(o.id) : false;
            const cx = (o.rect.x + o.rect.w / 2) * sx;
            const cy = (o.rect.y + o.rect.h / 2) * sx;
            return (
              <circle
                key={o.id}
                cx={cx}
                cy={cy}
                r={o.kind === "goal" ? 4.5 : 3.5}
                className={isFound ? "fill-honey" : o.kind === "goal" ? "fill-transparent stroke-honey/70" : "fill-white/35"}
                strokeWidth={o.kind === "goal" ? 1.5 : 0}
              />
            );
          })}
      </svg>
    </div>
  );
}
