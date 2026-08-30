import { createFileRoute } from "@tanstack/react-router";
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
      <div className="min-h-dvh flex items-center justify-center text-foreground">
        Poziom nie istnieje
      </div>
    );

  // All levels now run on the Phaser engine — LevelScene.ts is built
  // generically from LevelDef, so this was a routing change, not a rewrite
  // per level. The legacy Canvas2D engine (GameEngine, engine.ts) is kept
  // around unused rather than deleted, in case a regression surfaces here.
  return <PhaserGameCanvas level={level} />;
}
