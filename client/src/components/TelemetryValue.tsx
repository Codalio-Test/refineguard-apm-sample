import { ArrowDownRight, ArrowUpRight, Minus } from "lucide-react";

export default function TelemetryValue({ label, value, unit, trend, detail }: { label: string; value: string | number; unit?: string; trend?: "up" | "down" | "stable"; detail?: string }) {
  return (
    <div className="min-w-0">
    <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">{label}</p>
    <div className="mt-1 flex items-baseline gap-2">
    <span className="font-mono text-2xl font-semibold text-foreground">{value}</span>
    {unit && <span className="text-sm text-muted-foreground">{unit}</span>}
    </div>
    {trend && <div className={`mt-1 flex items-center gap-1 text-xs ${trend === "up" ? "text-red-600 dark:text-red-300" : trend === "down" ? "text-emerald-700 dark:text-emerald-300" : "text-muted-foreground"}`}>
    {trend === "up" ? <ArrowUpRight className="h-3 w-3" /> : trend === "down" ? <ArrowDownRight className="h-3 w-3" /> : <Minus className="h-3 w-3" />}
    {detail}
    </div>}
    </div>
  );
}

export { TelemetryValue };
