import { createFileRoute } from "@tanstack/react-router";
import { GameCanvas } from "@/components/game/GameCanvas";
import { getLevel } from "@/game/levels";

export const Route = createFileRoute("/poziom/$id")({
  head: ({ params }) => {
    const level = getLevel(params.id);
    return {
      meta: level ? [
        { title: `${level.title} — Przygody Edka` },
        { name: "description", content: level.subtitle },
      ] : [{ title: "Poziom — Przygody Edka" }],
    };
  },
  component: LevelPage,
});

function LevelPage() {
  const { id } = Route.useParams();
  const level = getLevel(id);

  return <GameCanvas level={level} />;
}
