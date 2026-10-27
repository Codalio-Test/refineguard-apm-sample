import { useState } from "react";
import { ChevronRight, Factory, Gauge, Search } from "lucide-react";
import { useModelIndex } from "@rhino-dev/rhino-react";
import { useNavigate } from "react-router-dom";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Input } from "../components/ui/input";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "../components/ui/tabs";

export default function Assets() {
  const navigate = useNavigate();
  const [query, setQuery] = useState("");
  const [selectedTag, setSelectedTag] = useState("");
  // `id` is the asset TAG: it is what the design's `/assets/${id}/health-summary`
  // navigation uses, so the projection keeps that key authoritative.
  const { data: assetResponse } = useModelIndex("assets", { search: query || undefined, perPage: 50 });
  const nodes = (assetResponse?.data ?? []).map((asset) => ({
    id: asset.asset_tag ?? String(asset.id ?? ""),
    record_id: asset.record_id ?? (typeof asset.id === "number" ? asset.id : null),
    unit: asset.unit ?? "",
    kind: asset.kind ?? asset.equipment_class ?? "",
    status: asset.status ?? "Normal",
    criticality: asset.criticality_class ?? "—",
    manufacturer: asset.manufacturer ?? "—",
    commissioned: asset.commissioned_on ? new Date(asset.commissioned_on).toLocaleDateString() : "—",
    completeness: asset.data_completeness_pct == null ? "—" : `${asset.data_completeness_pct}%`,
    flow: asset.rated_flow_m3h ?? "—",
    rpm: asset.rated_rpm ?? asset.design_speed_rpm ?? "—",
    maxTemp: asset.max_bearing_temp_c ?? "—",
    tagValidation: asset.last_tag_validation_at ?? null,
  }));
  const selected = nodes.find((node) => node.id === selectedTag) ?? nodes[0] ?? { id: "—", record_id: null, unit: "—", kind: "—", status: "Normal", criticality: "—", manufacturer: "—", commissioned: "—", completeness: "—", flow: "—", rpm: "—", maxTemp: "—", tagValidation: null };
  const selectedId = selected.record_id;
  const { data: componentResponse } = useModelIndex("asset_components", { filters: { asset_id: selectedId }, perPage: 50 }, { enabled: Boolean(selectedId) });
  const { data: tagResponse } = useModelIndex("historian_tags", { filters: { asset_id: selectedId }, perPage: 100 }, { enabled: Boolean(selectedId) });
  const components = componentResponse?.data ?? [];
  const tags = tagResponse?.data ?? [];
  const filtered = nodes.filter((node) => `${node.id} ${node.unit} ${node.kind}`.toLowerCase().includes(query.toLowerCase()));

  return (
    <div className="w-full min-w-0 space-y-8 lg:space-y-10">
      <section><p className="mb-1 text-xs font-medium uppercase tracking-wider text-muted-foreground">Configuration / Asset model</p><h1 className="text-2xl font-semibold text-foreground">Asset registry</h1><p className="mt-1 text-sm text-muted-foreground">Browse equipment identity, hierarchy, components, and telemetry mappings.</p></section>
      <section className="grid min-h-[620px] overflow-hidden rounded-xl border border-border/80 bg-card shadow-sm lg:grid-cols-[320px_1fr] xl:grid-cols-[360px_1fr]">
        <aside className="border-b border-border lg:border-b-0 lg:border-r"><div className="border-b border-border p-4"><div className="relative"><Search className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" /><Input className="h-9 pl-9" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search equipment" /></div></div><div className="border-b border-border bg-muted/50 px-4 py-2"><p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">BRR refinery complex</p></div><div className="p-2"><div className="flex items-center gap-2 px-2 py-2 text-sm font-medium"><Factory className="h-4 w-4 text-muted-foreground" />Rotating equipment</div>{filtered.map((node) => <button key={node.id} onClick={() => setSelectedTag(node.id)} className={`flex w-full items-center gap-3 border-l-2 px-3 py-3 text-left ${selected.id === node.id ? "border-primary bg-primary/5" : "border-transparent hover:bg-muted/60"}`}><div className="min-w-0 flex-1"><p className="font-mono text-sm font-semibold text-foreground">{node.id}</p><p className="truncate text-xs text-muted-foreground">{node.unit} · {node.kind}</p></div><ChevronRight className="h-4 w-4 text-muted-foreground" /></button>)}</div></aside>
        <div className="min-w-0"><div className="flex flex-col justify-between gap-5 border-b border-border p-5 sm:flex-row sm:items-center sm:p-6"><div><div className="flex items-center gap-3"><h2 className="font-mono text-xl font-semibold text-foreground">{selected.id}</h2><span className={`border px-2 py-0.5 text-xs font-medium ${selected.status === "Critical" ? "border-red-300 bg-red-50 text-red-700 dark:border-red-900 dark:bg-red-950 dark:text-red-300" : selected.status === "Advisory" ? "border-amber-300 bg-amber-50 text-amber-800 dark:border-amber-900 dark:bg-amber-950 dark:text-amber-300" : "border-emerald-300 bg-emerald-50 text-emerald-700 dark:border-emerald-900 dark:bg-emerald-950 dark:text-emerald-300"}`}>{selected.status}</span></div><p className="mt-1 text-sm text-muted-foreground">{selected.unit} / Rotating equipment / {selected.kind}</p></div><Button onClick={() => navigate(`/assets/${selected.id}/health-summary`)}><Gauge className="h-4 w-4" />Open health workspace</Button></div>
          <Tabs defaultValue="identity" className="p-5 sm:p-6"><TabsList className="h-10 w-full justify-start rounded-none border-b border-border bg-transparent p-0"><TabsTrigger value="identity" className="rounded-none border-b-2 border-transparent px-4 data-[state=active]:border-primary data-[state=active]:bg-transparent data-[state=active]:shadow-none">Identity</TabsTrigger><TabsTrigger value="components" className="rounded-none border-b-2 border-transparent px-4 data-[state=active]:border-primary data-[state=active]:bg-transparent data-[state=active]:shadow-none">Components</TabsTrigger><TabsTrigger value="envelope" className="rounded-none border-b-2 border-transparent px-4 data-[state=active]:border-primary data-[state=active]:bg-transparent data-[state=active]:shadow-none">Operating envelope</TabsTrigger><TabsTrigger value="tags" className="rounded-none border-b-2 border-transparent px-4 data-[state=active]:border-primary data-[state=active]:bg-transparent data-[state=active]:shadow-none">Tags</TabsTrigger></TabsList>
            <TabsContent value="identity" className="pt-6"><Card><CardHeader className="border-b border-border py-4"><CardTitle className="text-sm">Equipment identity</CardTitle></CardHeader><CardContent className="grid gap-x-8 gap-y-5 p-5 text-sm sm:grid-cols-2 xl:grid-cols-3">{[["Equipment class", selected.kind], ["Process unit", selected.unit], ["Criticality", selected.criticality], ["Manufacturer", selected.manufacturer], ["Commissioned", selected.commissioned], ["Data completeness", selected.completeness]].map(([label, value]) => <div key={label}><p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">{label}</p><p className="mt-1 text-foreground">{value}</p></div>)}</CardContent></Card></TabsContent>
            <TabsContent value="components" className="pt-6 text-sm text-muted-foreground">{components.length ? components.map((component) => component.component_name).filter(Boolean).join(" · ") : "No components recorded for this asset"}</TabsContent><TabsContent value="envelope" className="pt-6 text-sm text-muted-foreground">Rated flow {selected.flow} m³/h · Speed {selected.rpm} rpm · Maximum bearing temperature {selected.maxTemp} °C</TabsContent><TabsContent value="tags" className="pt-6 text-sm text-muted-foreground">{tags.length} historian tags mapped · Last validation {selected.tagValidation ? new Date(selected.tagValidation).toLocaleString() : "—"}</TabsContent>
          </Tabs>
        </div>
      </section>
    </div>
  );
}
