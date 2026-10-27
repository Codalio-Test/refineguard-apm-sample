import { Bell, Check, TriangleAlert } from "lucide-react";
import { SeverityBadge } from "./SeverityBadge";
import { Button } from "./ui/button";
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle, SheetTrigger } from "./ui/sheet";
import { useActiveAnomalies, useAcknowledgeIncident } from "../hooks/useApiQueries";

export default function GlobalAlertDrawer() {
  // The drawer reads the same anomaly endpoint the fleet dashboard does, so the
  // two surfaces can never disagree, and acknowledging writes through to the
  // incident record rather than dropping the row from local state.
  const { data } = useActiveAnomalies();
  const acknowledge = useAcknowledgeIncident();
  const alerts = (data ?? []).map((row) => ({ id: row.record_id, asset: row.asset_tag, message: row.issue, severity: row.severity }));
  return (
    <Sheet>
    <SheetTrigger asChild><Button variant="ghost" size="icon" className="relative" aria-label="Open alerts"><Bell className="h-5 w-5" /><span className="absolute right-1 top-1 h-2 w-2 rounded-full bg-red-500" /></Button></SheetTrigger>
    <SheetContent className="w-full sm:max-w-md"><SheetHeader><SheetTitle>Active alerts</SheetTitle><SheetDescription>Prioritized machinery events across the fleet.</SheetDescription></SheetHeader>
    <div className="mt-6 space-y-3">{alerts.length ? alerts.map((alert) => <div key={alert.id} className="rounded-lg border border-border bg-card p-4"><div className="flex items-start justify-between gap-3"><div><p className="font-medium text-foreground">{alert.asset}</p><p className="mt-1 text-sm text-muted-foreground">{alert.message}</p></div><SeverityBadge severity={alert.severity} /></div><Button variant="ghost" size="sm" className="mt-3" onClick={() => acknowledge.mutate(alert.id)} disabled={acknowledge.isPending}><Check className="h-4 w-4" />Acknowledge</Button></div>) : <div className="py-12 text-center text-muted-foreground"><TriangleAlert className="mx-auto mb-3 h-8 w-8" /><p>No unacknowledged alerts</p></div>}</div>
    </SheetContent>
    </Sheet>
  );
}

export { GlobalAlertDrawer };
