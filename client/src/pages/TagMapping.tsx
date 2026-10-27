import { SeverityBadge } from "../components/SeverityBadge";
import React, { useState } from "react";
import { useModelIndex, useNestedOperations } from "@rhino-dev/rhino-react";
import { useFileImport, useTagValidation } from "../hooks/useApiQueries";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Checkbox } from "../components/ui/checkbox";
import { Input } from "../components/ui/input";
import { useSearchParams } from "react-router-dom";
import { Progress } from "../components/ui/progress";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../components/ui/table";

function TagMappingSection0() {
  const [searchParams,setSearchParams]=useSearchParams();
  const query=searchParams.get("q")??"";
  const connectorOnly=searchParams.get("connector")==="pi";
  const unitOnly=searchParams.get("unit")==="cdu1";
  const setParam=(key:string,value:string|null)=>{const params=new URLSearchParams(searchParams); if(value) params.set(key,value); else params.delete(key); setSearchParams(params,{replace:true});};
  const { data: tagResponse } = useModelIndex("historian_tags", { search: query||undefined, perPage: 200 });
  const tags = tagResponse?.data ?? [];
  const validate = useTagValidation();
  const importTags = useFileImport('/historian_tags/import', 'historian_tags');
  const handleFile = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;
    const content = await file.text();
    importTags.mutate({ filename: file.name, content });
    event.target.value = "";
  };
  const status = validate.data
    ? `${validate.data.passed} tags validated · ${validate.data.failed} rejected · ${validate.data.duration_ms}ms (budget ${validate.data.budget_ms}ms)`
    : importTags.isSuccess
      ? `${tags.length} historian tags imported`
      : `${tags.length} historian tags discovered`;
  return (
    <section className="space-y-4"><div><h1 className="text-2xl font-semibold">Tag Mapping</h1><p className="text-sm text-muted-foreground">{status}</p></div><div className="flex flex-wrap gap-2"><Input className="max-w-sm" value={query} onChange={(e)=>setParam("q",e.target.value||null)} placeholder="Search historian tags"/><Button variant={connectorOnly?"default":"outline"} onClick={()=>setParam("connector",connectorOnly?null:"pi")}>Connector: {connectorOnly?"PI":"All"}</Button><Button variant={unitOnly?"default":"outline"} onClick={()=>setParam("unit",unitOnly?null:"cdu1")}>Unit: {unitOnly?"CDU-1":"All"}</Button><Button onClick={()=>validate.mutate({})} disabled={validate.isPending}>{validate.isPending?"Validating…":"Auto-map"}</Button><Button variant="outline" onClick={()=>document.getElementById("tag-mapping-import")?.click()} disabled={importTags.isPending}>{importTags.isPending?"Importing…":"Import CSV"}</Button><input id="tag-mapping-import" type="file" accept=".csv,.json" className="hidden" onChange={handleFile}/></div></section>
  );
}

function TagMappingSection1() {
  const [searchParams]=useSearchParams();
  const query=searchParams.get("q")??"";
  const connectorOnly=searchParams.get("connector")==="pi";
  const unitOnly=searchParams.get("unit")==="cdu1";
  const { data: connectorResponse } = useModelIndex("historian_connectors", { perPage: 20 });
  const piConnector = (connectorResponse?.data ?? []).find((connector) => (connector.historian_type ?? "").includes("OSIsoft")) ?? null;
  const { data: tagResponse } = useModelIndex("historian_tags", {
    search: query||undefined,
    filters: connectorOnly && piConnector?.id ? { historian_connector_id: piConnector.id } : undefined,
    includes: ["asset", "asset_component", "historian_connector"],
    perPage: 200,
  });
  const rows = (tagResponse?.data ?? [])
    .filter((tag) => !unitOnly || ((tag as { asset?: { unit?: string } }).asset?.unit ?? "") === "CDU-1")
    .map((tag) => [
      tag.tag_path ?? "\u2014",
      tag.asset_tag ?? (tag as { asset?: { asset_tag?: string } }).asset?.asset_tag ?? "\u2014",
      tag.component_name ?? (tag as { asset_component?: { component_name?: string } }).asset_component?.component_name ?? "\u2014",
      tag.measurement_type ?? "\u2014",
      tag.engineering_unit ?? "\u2014",
      tag.quality_status ?? "\u2014",
      tag.mapping_state ?? (tag.mapped ? "Mapped" : "Unmapped"),
      tag.compatible === false || tag.stale ? "critical" : "healthy",
    ]);
  return (
    <section className="overflow-x-auto rounded-lg border bg-card"><Table><TableHeader><TableRow>{["Select","Historian tag","Asset","Component","Measurement","Units","Quality","State"].map((h)=><TableHead key={h}>{h}</TableHead>)}</TableRow></TableHeader><TableBody>{rows.map((r)=><TableRow key={r[0]} className={r[7] === "critical" ? "bg-destructive/10" : undefined}><TableCell><Checkbox/></TableCell>{r.slice(0, 6).map((c,i)=><TableCell key={`${r[0]}-${i}`} className={i===0?"font-mono text-xs":"text-xs"}>{c}</TableCell>)}<TableCell><SeverityBadge severity={r[7]} label={r[6]}/></TableCell></TableRow>)}</TableBody></Table></section>
  );
}

function TagMappingSection2() {
  const [committed,setCommitted]=useState(false);
  const nested = useNestedOperations();
  const { data: tagResponse } = useModelIndex("historian_tags", { perPage: 200 });
  const tags = tagResponse?.data ?? [];
  const compatible = tags.filter((tag) => tag.compatible !== false).length;
  const unmapped = tags.filter((tag) => !tag.mapped && tag.id);
  const commitMappings = () => {
    if (!unmapped.length) {
      setCommitted(true);
      return;
    }
    nested.mutate(
      {
        operations: unmapped.map((tag) => ({
          action: "update" as const,
          model: "historian_tags",
          id: tag.id as number,
          data: { mapped: true, mapping_state: "Mapped", asset_id: tag.asset_id ?? undefined, asset_component_id: tag.asset_component_id ?? undefined },
        })),
      },
      { onSuccess: () => setCommitted(true) },
    );
  };
  return (
    <section className="grid gap-3 lg:grid-cols-2"><Card><CardHeader><CardTitle className="text-base">Signal preview</CardTitle></CardHeader><CardContent><svg viewBox="0 0 500 140" className="h-44 w-full text-primary"><polyline points="0,90 50,85 100,95 150,70 200,82 250,48 300,62 350,35 400,55 450,28 500,45" fill="none" stroke="currentColor" strokeWidth="2"/></svg></CardContent></Card><Card><CardHeader><CardTitle className="text-base">Validation summary</CardTitle></CardHeader><CardContent><Progress value={tags.length ? Math.round((compatible / tags.length) * 100) : 0}/><p className="my-3 text-sm text-muted-foreground">{compatible} of {tags.length} mappings pass all compatibility and freshness checks.</p><Button onClick={commitMappings} disabled={committed || nested.isPending}>{committed?"Mappings committed":nested.isPending?"Committing…":"Commit valid mappings"}</Button></CardContent></Card></section>
  );
}

export default function TagMapping() {
  return (
    <div className="w-full min-w-0 overflow-x-hidden">
      <div className="flex flex-col gap-4 w-full min-w-0">
        <TagMappingSection0 />
        <TagMappingSection1 />
        <TagMappingSection2 />
      </div>
    </div>
  );
}
