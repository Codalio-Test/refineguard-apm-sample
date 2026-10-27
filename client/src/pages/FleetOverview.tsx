import { useState } from "react";
import { ArrowDown, ArrowUp, Search, SlidersHorizontal } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { useModelIndex } from "@rhino-dev/rhino-react";
import { useActiveAnomalies, useFleetOverview } from "../hooks/useApiQueries";
import type { Asset } from "../types/rhino";
import { SeverityBadge } from "../components/SeverityBadge";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Input } from "../components/ui/input";
import { Progress } from "../components/ui/progress";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../components/ui/table";

export default function FleetOverview() {
  const navigate = useNavigate();
  const [search, setSearch] = useState("");
  const [unit, setUnit] = useState("all");
  const [showTemperature, setShowTemperature] = useState(true);
  // Rows and KPIs come from the API; the design's `id` is the asset tag, which
  // is what the locked row-navigation URLs are built from.
  const { data: assetResponse } = useModelIndex<Asset>("assets", { perPage: 50 });
  const { data: overview } = useFleetOverview();
  const { data: anomalyQueue } = useActiveAnomalies();
  const assets = (assetResponse?.data ?? []).map((asset) => ({ ...asset, id: asset.asset_tag ?? String(asset.id ?? ""), name: asset.name ?? asset.asset_name ?? "" }));
  const filtered = assets.filter((asset) => (unit === "all" || asset.unit === unit) && `${asset.id} ${asset.name}`.toLowerCase().includes(search.toLowerCase()));
  const metrics = (overview?.kpis ?? []).map((kpi) => ({ label: kpi.label, value: kpi.value === null || kpi.value === undefined ? "—" : String(kpi.value), note: kpi.note, direction: kpi.direction === "down" ? "down" : "up" }));
  const unitRisk = (overview?.unit_risk ?? []).map((row) => ({ n: row.name, v: row.exposure_percent ?? 0 }));
  const anomalies = anomalyQueue ?? [];

  return (
    <div className="w-full min-w-0 space-y-8 lg:space-y-10">
      <section className="flex flex-col justify-between gap-5 md:flex-row md:items-center">
        <div><p className="mb-1 text-xs font-medium uppercase tracking-wider text-muted-foreground">Operations / Machinery health</p><h1 className="text-2xl font-semibold text-foreground">Fleet overview</h1><p className="mt-1 text-sm text-muted-foreground">Current condition and prioritized risk across the refinery.</p></div>
        <div className="flex items-center gap-2 text-xs text-muted-foreground"><span className="h-2 w-2 rounded-full bg-emerald-500" />Live telemetry<span className="text-border">|</span>{overview ? `Updated ${new Date(overview.generated_at).toLocaleTimeString()}` : "Awaiting telemetry"}</div>
      </section>

      <section className="grid overflow-hidden rounded-xl border border-border/80 bg-card shadow-[0_1px_2px_rgba(15,23,42,0.04),0_10px_30px_rgba(15,23,42,0.05)] sm:grid-cols-2 xl:grid-cols-4">
        {metrics.map((item, index) => <div key={item.label} className={`border-t-2 p-5 xl:p-6 ${index === 0 ? "border-t-blue-500" : index === 1 ? "border-t-amber-500 sm:border-l sm:border-l-border" : index === 2 ? "border-t-rose-500 sm:border-l-0 xl:border-l xl:border-l-border" : "border-t-emerald-500 sm:border-l sm:border-l-border"}`}><p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">{item.label}</p><div className="mt-2 flex items-end justify-between gap-3"><p className={`font-mono text-2xl font-semibold tabular-nums ${index === 0 ? "text-blue-600 dark:text-blue-400" : index === 1 ? "text-amber-600 dark:text-amber-400" : index === 2 ? "text-rose-600 dark:text-rose-400" : "text-emerald-600 dark:text-emerald-400"}`}>{item.value}</p><p className={`flex items-center gap-1 text-xs ${item.label === "Critical" ? "text-destructive" : "text-muted-foreground"}`}>{item.direction === "up" ? <ArrowUp className="h-3 w-3" /> : <ArrowDown className="h-3 w-3" />}{item.note}</p></div></div>)}
      </section>

      <section className="space-y-5">
        <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between"><div><h2 className="text-base font-semibold text-foreground">Asset priority queue</h2><p className="text-xs text-muted-foreground">Sorted by health index and process criticality</p></div><div className="flex flex-col gap-2 sm:flex-row"><div className="relative sm:w-64"><Search className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" /><Input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search asset or tag" className="h-9 pl-9" /></div><Select value={unit} onValueChange={setUnit}><SelectTrigger className="h-9 w-full sm:w-40"><SelectValue /></SelectTrigger><SelectContent><SelectItem value="all">All process units</SelectItem><SelectItem value="CDU-1">CDU-1</SelectItem><SelectItem value="FCC-2">FCC-2</SelectItem><SelectItem value="HCU-3">HCU-3</SelectItem></SelectContent></Select><Button variant="outline" size="sm" onClick={() => setShowTemperature((visible) => !visible)}><SlidersHorizontal className="h-4 w-4" />{showTemperature ? "Hide temperature" : "Show temperature"}</Button></div></div>
        <div className="overflow-x-auto rounded-xl border border-border/80 bg-card shadow-[0_1px_2px_rgba(15,23,42,0.04),0_8px_24px_rgba(15,23,42,0.04)]"><Table><TableHeader><TableRow><TableHead>Status</TableHead><TableHead>Asset</TableHead><TableHead>Unit</TableHead><TableHead>Health</TableHead><TableHead className="text-right">RMS mm/s</TableHead>{showTemperature && <TableHead className="text-right">Bearing °C</TableHead>}<TableHead>Est. RUL</TableHead><TableHead>Last sample</TableHead></TableRow></TableHeader><TableBody>{filtered.map((asset) => <TableRow key={asset.id} className="cursor-pointer" onClick={() => navigate(`/assets/${asset.id}/health-summary`)}><TableCell><SeverityBadge severity={asset.severity} /></TableCell><TableCell><p className="font-mono text-sm font-semibold text-foreground">{asset.id}</p><p className="text-xs text-muted-foreground">{asset.name}</p></TableCell><TableCell className="text-sm">{asset.unit}</TableCell><TableCell className="min-w-36"><div className="flex items-center gap-3"><Progress value={asset.health} className="h-1.5" /><span className="w-7 text-right font-mono text-xs tabular-nums">{asset.health}</span></div></TableCell><TableCell className="text-right font-mono text-sm tabular-nums">{asset.rms}</TableCell>{showTemperature && <TableCell className="text-right font-mono text-sm tabular-nums">{asset.temp}</TableCell>}<TableCell className="text-sm">{asset.rul}</TableCell><TableCell className="font-mono text-xs text-muted-foreground">{asset.sample} ago</TableCell></TableRow>)}</TableBody></Table></div>
      </section>

      <section className="grid gap-6 lg:grid-cols-5"><Card className="rounded-xl border-border/80 lg:col-span-2"><CardHeader className="border-b border-border py-4"><CardTitle className="text-sm font-semibold">Risk by process unit</CardTitle></CardHeader><CardContent className="space-y-5 p-5">{unitRisk.map((item) => <div key={item.n}><div className="mb-2 flex justify-between text-xs"><span className="font-medium">{item.n}</span><span className="font-mono text-muted-foreground">{item.v}% exposure</span></div><Progress value={item.v} className="h-1.5" /></div>)}</CardContent></Card><Card className="rounded-xl border-border/80 lg:col-span-3"><CardHeader className="border-b border-border py-4"><CardTitle className="text-sm font-semibold">Active anomaly queue</CardTitle></CardHeader><CardContent className="divide-y divide-border p-0">{anomalies.map((item) => <button key={item.id} className="flex w-full items-center gap-4 px-5 py-3 text-left hover:bg-muted/50" onClick={() => navigate(`/assets/${item.id}/diagnostics`)}><span className="font-mono text-xs font-semibold text-primary">{item.id}</span><span className="flex-1 text-sm text-foreground">{item.issue}</span><span className="text-xs text-muted-foreground">{item.age}</span></button>)}</CardContent></Card></section>
    </div>
  );
}
