import { SeverityBadge } from "../components/SeverityBadge";
import React, { useState } from "react";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Checkbox } from "../components/ui/checkbox";
import { Input } from "../components/ui/input";
import { Progress } from "../components/ui/progress";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../components/ui/table";

function TagMappingSection0() {
  const [status,setStatus]=useState("192 historian tags discovered");
  const [connector,setConnector]=useState(false);
  const [unit,setUnit]=useState(false);
  return (
    <section className="space-y-4"><div><h1 className="text-2xl font-semibold">Tag Mapping</h1><p className="text-sm text-muted-foreground">{status}</p></div><div className="flex flex-wrap gap-2"><Input className="max-w-sm" placeholder="Search historian tags"/><Button variant={connector?"default":"outline"} onClick={()=>setConnector(!connector)}>Connector: {connector?"PI":"All"}</Button><Button variant={unit?"default":"outline"} onClick={()=>setUnit(!unit)}>Unit: {unit?"CDU-1":"All"}</Button><Button onClick={()=>setStatus("184 compatible tags mapped automatically")}>Auto-map</Button><Button variant="outline" onClick={()=>setStatus("CSV import ready · choose a local file")}>Import CSV</Button></div></section>
  );
}

function TagMappingSection1() {
  return (
    <section className="overflow-x-auto rounded-lg border bg-card"><Table><TableHeader><TableRow>{["Select","Historian tag","Asset","Component","Measurement","Units","Quality","State"].map((h)=><TableHead key={h}>{h}</TableHead>)}</TableRow></TableHeader><TableBody>{[["PI:P204A.VIB.OH","P-204A","OB Bearing","Velocity","mm/s","Good"],["PI:P204A.TEMP.DE","P-204A","DE Bearing","Temperature","°C","Good"]].map((r)=><TableRow key={r[0]}><TableCell><Checkbox/></TableCell>{r.map((c,i)=><TableCell key={c} className={i===0?"font-mono text-xs":"text-xs"}>{c}</TableCell>)}<TableCell><SeverityBadge severity="healthy" label="Mapped"/></TableCell></TableRow>)}</TableBody></Table></section>
  );
}

function TagMappingSection2() {
  const [committed,setCommitted]=useState(false);
  return (
    <section className="grid gap-3 lg:grid-cols-2"><Card><CardHeader><CardTitle className="text-base">Signal preview</CardTitle></CardHeader><CardContent><svg viewBox="0 0 500 140" className="h-44 w-full text-primary"><polyline points="0,90 50,85 100,95 150,70 200,82 250,48 300,62 350,35 400,55 450,28 500,45" fill="none" stroke="currentColor" strokeWidth="2"/></svg></CardContent></Card><Card><CardHeader><CardTitle className="text-base">Validation summary</CardTitle></CardHeader><CardContent><Progress value={96}/><p className="my-3 text-sm text-muted-foreground">184 of 192 mappings pass all compatibility and freshness checks.</p><Button onClick={()=>setCommitted(true)} disabled={committed}>{committed?"Mappings committed":"Commit valid mappings"}</Button></CardContent></Card></section>
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
