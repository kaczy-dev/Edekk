import { cn } from "@/lib/utils";

interface Option<T extends string | number> {
  value: T;
  label: string;
}

interface Props<T extends string | number> {
  options: Option<T>[];
  value: T;
  onChange: (value: T) => void;
  className?: string;
}

export function SegmentedControl<T extends string | number>({
  options,
  value,
  onChange,
  className,
}: Props<T>) {
  return (
    <div className={cn("grid gap-2", className)} style={{ gridTemplateColumns: `repeat(${options.length}, 1fr)` }}>
      {options.map((opt) => (
        <button
          key={opt.value}
          onClick={() => onChange(opt.value)}
          className={cn(
            "rounded-2xl border px-4 py-3 text-sm font-medium transition",
            value === opt.value
              ? "border-primary bg-primary/15 text-foreground"
              : "border-border bg-muted/40 text-muted-foreground hover:text-foreground",
          )}
        >
          {opt.label}
        </button>
      ))}
    </div>
  );
}
