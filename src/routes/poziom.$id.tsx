import { createFileRoute, useParams, useSearch } from "@tanstack/react-router";
import { GameCanvas } from "@/components/game/GameCanvas";
import { getLevel } from "@/game/levels";
import { z } from "zod";

const searchSchema = z.object({
  mode: z.enum(["play", "explore"]).optional().catch("play"),
});

export const Route = createFileRoute("/poziom/$id")({
  validateSearch: (search) => searchSchema.parse(search),
  head: ({ params }) => {
    const l = getLevel(params.id);
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
  const { mode } = useSearch({ from: "/poziom/$id" });
  const level = getLevel(id);
  return <GameCanvas key={level.id} level={level} mode={mode ?? "play"} />;
}
