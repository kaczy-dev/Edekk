import { createFileRoute, notFound, useParams } from "@tanstack/react-router";
import { GameCanvas } from "@/components/game/GameCanvas";
import { getLevel } from "@/game/levels";

export const Route = createFileRoute("/poziom/$id")({
  // Validate only — returning the level would hand the component a fresh object
  // per render (loader data is re-serialised), and GameCanvas's trackers key
  // their animation loops off the level's identity.
  loader: ({ params }) => {
    if (!getLevel(params.id)) throw notFound();
  },
  head: ({ params }) => {
    const l = getLevel(params.id);
    if (!l) return { meta: [{ title: "Nie znaleziono poziomu — Przygody Edka" }] };
    return {
      meta: [
        { title: `${l.title} — Przygody Edka` },
        { name: "description", content: `${l.title}: ${l.subtitle}. ${l.objective}` },
      ],
    };
  },
  component: LevelPage,
});

function LevelPage() {
  const { id } = useParams({ from: "/poziom/$id" });
  // Stable reference straight out of the LEVELS module.
  const level = getLevel(id);
  if (!level) throw notFound();
  return <GameCanvas key={level.id} level={level} />;
}
