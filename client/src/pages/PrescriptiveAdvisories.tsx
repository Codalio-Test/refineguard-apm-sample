import { SeverityBadge } from "../components/SeverityBadge";
import React from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { useModelIndex } from "@rhino-dev/rhino-react";
import type { PrescriptiveAdvisory } from "../types/rhino";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Input } from "../components/ui/input";
import { Progress } from "../components/ui/progress";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../components/ui/table";

function PrescriptiveAdvisoriesSection0() {
  // Search, sort and selection travel in the URL so the row table and the
  // intervention card below read exactly what the operator chose.
  const [searchParams,setSearchParams]=useSearchParams();
  const filter=searchParams.get("sort")??"Shortest RUL";
  const query=searchParams.get("q")??"";
  const update=(key:string,value:string)=>{const params=new URLSearchParams(searchParams); if(value) params.set(key,value); else params.delete(key); setSearchParams(params,{replace:true});};
  const setFilter=(value:string)=>update("sort",value);
  const setQuery=(value:string)=>update("q",value);
  return (
    <section className="space-y-4"><div><h1 className="text-2xl font-semibold">Prescriptive Advisories</h1><p className="text-sm text-muted-foreground">{query?`Filtering advisories by “${query}”`:"Prioritize intervention by RUL and production consequence."}</p></div><div className="flex flex-wrap gap-2"><Input className="max-w-sm" value={query} onChange={(e)=>setQuery(e.target.value)} placeholder="Search advisory or asset"/>{["State","Unit","RUL window","Shortest RUL"].map((item)=><Button key={item} variant={filter===item?"default":"outline"} onClick={()=>setFilter(item)}>{item}</Button>)}</div></section>
  );
}

function PrescriptiveAdvisoriesSection1() {
  const [searchParams,setSearchParams]=useSearchParams();
  const query=searchParams.get("q")??"";
  const sort=searchParams.get("sort")??"Shortest RUL";
  const { data: listResponse } = useModelIndex<PrescriptiveAdvisory>("prescriptive_advisories", { includes: ["diagnostic_incident"], search: query||undefined, sort: sort==="Shortest RUL"?"-due_within_days":"-urgency", perPage: 50 });
  const rows=(listResponse?.data??[]).map((row)=>({
    id: row.id,
    asset: row.asset_tag ?? String(row.id ?? ""),
    finding: row.finding ?? row.recommendation ?? row.recommended_action ?? "—",
    rul: row.rul_window ?? "—",
    pf: row.pf_interval_days == null ? "—" : `${row.pf_interval_days} d`,
    rec: row.recommendation ?? row.recommended_action ?? "—",
    s: row.severity ?? "info",
    cmms: row.status ?? "Draft",
  }));
  const selected=searchParams.get("advisory")??"";
  const setSelected=(tag:string)=>{const params=new URLSearchParams(searchParams); params.set("advisory",tag); setSearchParams(params,{replace:true});};
  return (
    <section className="overflow-x-auto rounded-lg border border-border bg-card"><Table><TableHeader><TableRow>{["Priority","Asset","Finding","RUL window","P-F interval","Recommendation","CMMS"].map((h)=><TableHead key={h}>{h}</TableHead>)}</TableRow></TableHeader><TableBody>{rows.map((r)=><TableRow key={r.id ?? r.asset} onClick={()=>setSelected(r.asset)} className={selected===r.asset?"bg-muted":"cursor-pointer"}><TableCell><SeverityBadge severity={r.s}/></TableCell><TableCell className="font-mono">{r.asset}</TableCell><TableCell>{r.finding}</TableCell><TableCell>{r.rul}</TableCell><TableCell>{r.pf}</TableCell><TableCell>{r.rec}</TableCell><TableCell>{r.cmms}</TableCell></TableRow>)}</TableBody></Table></section>
  );
}

function PrescriptiveAdvisoriesSection2() {
  const navigate=useNavigate();
  const [searchParams]=useSearchParams();
  const { data: listResponse } = useModelIndex<PrescriptiveAdvisory>("prescriptive_advisories", { includes: ["diagnostic_incident"], perPage: 50 });
  const rows = listResponse?.data ?? [];
  const selectedTag = searchParams.get("advisory");
  const advisory = rows.find((row) => row.asset_tag === selectedTag) ?? rows[0] ?? null;
  const steps = advisory?.action_steps_json ?? [];
  return (
    <section className="grid gap-3 lg:grid-cols-[1fr_360px]"><Card><CardHeader><CardTitle className="text-base">Recommended intervention · {advisory?.asset_tag ?? "—"}</CardTitle></CardHeader><CardContent><ol className="list-decimal space-y-2 pl-5 text-sm text-muted-foreground">{steps.map((step)=><li key={step}>{step}</li>)}</ol><Button className="mt-5" onClick={()=>navigate("/work-orders/confirmation",{state:{advisoryId:advisory?.id}})}>Create work order</Button></CardContent></Card><Card><CardHeader><CardTitle className="text-base">RUL confidence</CardTitle></CardHeader><CardContent><p className="font-mono text-3xl">{advisory?.rul_window ?? "—"}</p><Progress value={advisory?.regime_confidence_pct ?? 0} className="mt-4"/><p className="mt-2 text-xs text-muted-foreground">Bearing lead time: {advisory?.parts_lead_time_days ?? "—"} days · {advisory?.warehouse_status ?? "—"}</p></CardContent></Card></section>
  );
}

export default function PrescriptiveAdvisories() {
  return (
    <div className="w-full min-w-0 overflow-x-hidden">
      <div className="flex flex-col gap-4 w-full min-w-0">
        <PrescriptiveAdvisoriesSection0 />
        <PrescriptiveAdvisoriesSection1 />
        <PrescriptiveAdvisoriesSection2 />
      </div>
    </div>
  );
}
