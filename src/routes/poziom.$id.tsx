import { createFileRoute, Link } from "@tanstack/react-router";
import { PhaserGameCanvas } from "@/components/game/PhaserGameCanvas";
import { getLevel } from "@/game/levels";

export const Route = createFileRoute("/poziom/$id")({
  head: ({ params }) => {
    const level = getLevel(params.id);
    return {
      meta: level
        ? [
            { title: `${level.title} — Przygody Edka` },
            { name: "description", content: level.subtitle },
          ]
        : [{ title: "Poziom — Przygody Edka" }],
    };
  },
  component: LevelPage,
});

function LevelPage() {
  const { id } = Route.useParams();
  const level = getLevel(id);

  if (!level)
    return (
      <div className="min-h-dvh flex flex-col items-center justify-center gap-4 text-foreground px-4">
        <p className="text-lg font-semibold">Poziom nie istnieje</p>
        <Link
          to="/menu"
          className="rounded-full bg-primary px-6 py-2.5 text-sm font-medium text-primary-foreground transition hover:opacity-90 active:scale-95"
        >
          Wróć do wyboru poziomów
        </Link>
      </div>
    );

  // All levels now run on the Phaser engine — LevelScene.ts is built
  // generically from LevelDef, so this was a routing change, not a rewrite
  // per level. The legacy Canvas2D engine (GameEngine, engine.ts) is kept
  // around unused rather than deleted, in case a regression surfaces here.
  return <PhaserGameCanvas level={level} />;
}
