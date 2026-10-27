import { AlertTriangle, CircleCheck, CircleX, Info } from "lucide-react";
import { Badge } from "./ui/badge";

const styles: Record<string, string> = {
  critical: "border-red-300 bg-red-100 text-red-900 dark:border-red-800 dark:bg-red-950 dark:text-red-200",
  warning: "border-amber-300 bg-amber-100 text-amber-950 dark:border-amber-700 dark:bg-amber-950 dark:text-amber-200",
  healthy: "border-emerald-300 bg-emerald-100 text-emerald-900 dark:border-emerald-800 dark:bg-emerald-950 dark:text-emerald-200",
  info: "border-blue-300 bg-blue-100 text-blue-900 dark:border-blue-800 dark:bg-blue-950 dark:text-blue-200",
};

export default function SeverityBadge({ severity = "info", label }: { severity?: string; label?: string }) {
  const normalizedSeverity = severity.toLowerCase();
  const Icon = normalizedSeverity === "critical" ? CircleX : normalizedSeverity === "warning" ? AlertTriangle : normalizedSeverity === "healthy" ? CircleCheck : Info;

  return (
    <Badge
      variant="outline"
      className={`min-w-[5.75rem] justify-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-bold uppercase tracking-[0.06em] shadow-sm ${styles[normalizedSeverity] ?? styles.info}`}
    >
      <Icon className="h-3.5 w-3.5 shrink-0" aria-hidden="true" />
      {label ?? normalizedSeverity}
    </Badge>
  );
}

export { SeverityBadge };