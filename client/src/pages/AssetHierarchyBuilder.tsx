import { CircleCheck } from "lucide-react";
import React, { useState } from "react";
import { useModelIndex, useModelUpdate } from "@rhino-dev/rhino-react";
import type { HierarchyNode } from "../types/rhino";
import { useHierarchyTree, useValidateHierarchy } from "../hooks/useApiQueries";
import { Alert, AlertDescription, AlertTitle } from "../components/ui/alert";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Input } from "../components/ui/input";
import { Label } from "../components/ui/label";

function AssetHierarchyBuilderSection0() {
  const [status,setStatus]=useState("ISA-95 / ISO 14224");
  const validate = useValidateHierarchy();
  return (
    <section className="flex flex-wrap items-center gap-2"><div className="mr-auto"><h1 className="text-2xl font-semibold">Asset Hierarchy Builder</h1><p className="text-sm text-muted-foreground">{status}</p></div>{["unit","train","asset"].map((item)=><Button key={item} variant="outline" onClick={()=>setStatus(`New ${item} added to draft`)}>Add {item}</Button>)}<Button onClick={()=>validate.mutate()} disabled={validate.isPending}>{validate.isPending?"Validating…":"Validate & publish"}</Button></section>
  );
}

function AssetHierarchyBuilderSection1() {
  const { data: tree } = useHierarchyTree();
  const { data: assetResponse } = useModelIndex("assets", { perPage: 200 });
  const assets = assetResponse?.data ?? [];
  const update = useModelUpdate("assets");
  const [nodeTag,setNodeTag]=useState("");
  const [tag,setTag]=useState("");
  const [equipmentClass,setEquipmentClass]=useState("");
  const [manufacturer,setManufacturer]=useState("");
  const [criticality,setCriticality]=useState("");
  const [saved,setSaved]=useState(false);
  const flatten=(items: HierarchyNode[], depth=0): Array<{ id: string; text: string; label: string }> =>
    items.flatMap((item) => [
      { id: item.id, text: `${"  ".repeat(depth)}${depth ? "└ " : ""}${item.label ?? item.asset_tag ?? item.id}`, label: item.asset_tag ?? item.label ?? "" },
      ...flatten(item.children ?? [], depth + 1),
    ]);
  const treeLines = flatten(tree ?? []);
  const selectedTag = nodeTag || treeLines[0]?.label || "";
  const selected = assets.find((asset) => asset.asset_tag === selectedTag) ?? null;
  const saveMetadata = () => {
    if (!selected?.id) return;
    setSaved(false);
    update.mutate(
      {
        id: selected.id,
        data: {
          asset_name: selected.asset_name,
          asset_tag: tag || selected.asset_tag,
          equipment_class: equipmentClass || selected.equipment_class,
          manufacturer: manufacturer || selected.manufacturer,
          criticality_class: criticality || selected.criticality_class,
        },
      },
      { onSuccess: () => setSaved(true) },
    );
  };
  return (
    <section className="grid gap-3 xl:grid-cols-[360px_1fr]"><Card><CardHeader><CardTitle className="text-base">Equipment tree</CardTitle></CardHeader><CardContent className="space-y-1">{treeLines.map((n)=><button key={n.id} onClick={()=>{setNodeTag(n.label); setSaved(false);}} className="block w-full rounded p-2 text-left font-mono text-xs hover:bg-muted">{n.text}</button>)}</CardContent></Card><Card><CardHeader><CardTitle className="text-base">{selectedTag || "No node selected"}</CardTitle></CardHeader><CardContent className="grid gap-3 md:grid-cols-2"><div><Label>Equipment tag</Label><Input value={tag} onChange={(e)=>{setTag(e.target.value); setSaved(false);}} placeholder={selected?.asset_tag ?? "P-204A"}/></div><div><Label>Class</Label><Input value={equipmentClass} onChange={(e)=>{setEquipmentClass(e.target.value); setSaved(false);}} placeholder={selected?.equipment_class ?? "Centrifugal pump"}/></div><div><Label>Manufacturer</Label><Input value={manufacturer} onChange={(e)=>{setManufacturer(e.target.value); setSaved(false);}} placeholder={selected?.manufacturer ?? "Sulzer"}/></div><div><Label>Criticality</Label><Input value={criticality} onChange={(e)=>{setCriticality(e.target.value); setSaved(false);}} placeholder={selected?.criticality_class ?? "Production critical"}/></div><Button onClick={saveMetadata} disabled={!selected?.id || update.isPending}>{saved?"Metadata saved":"Save metadata"}</Button></CardContent></Card></section>
  );
}

function AssetHierarchyBuilderSection2() {
  const validate = useValidateHierarchy();
  const payload = (validate.data ?? null) as Record<string, unknown> | null;
  const rawErrors = payload?.errors;
  const failures = Array.isArray(rawErrors) ? rawErrors.map(String) : [];
  const summary = typeof payload?.summary === "string" ? (payload.summary as string) : null;
  const failed = payload?.valid === false || failures.length > 0;
  return (
    <section><Alert variant={failed?"destructive":"default"}><CircleCheck className="h-4 w-4"/><AlertTitle>{failed?"Hierarchy validation failed":"Hierarchy validation passed"}</AlertTitle><AlertDescription>{summary ?? (failures.length ? failures.join(" · ") : "Unique tags, parent integrity, required metadata, and historian bindings are validated before the hierarchy is published.")}</AlertDescription></Alert></section>
  );
}

export default function AssetHierarchyBuilder() {
  return (
    <div className="w-full min-w-0 overflow-x-hidden">
      <div className="flex flex-col gap-4 w-full min-w-0">
        <AssetHierarchyBuilderSection0 />
        <AssetHierarchyBuilderSection1 />
        <AssetHierarchyBuilderSection2 />
      </div>
    </div>
  );
}
