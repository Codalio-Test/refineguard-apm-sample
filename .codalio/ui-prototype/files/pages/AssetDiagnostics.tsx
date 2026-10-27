import { AssetContextNavigation } from "../components/AssetContextNavigation";
import { ExplainabilityEvidence } from "../components/ExplainabilityEvidence";
import { SeverityBadge } from "../components/SeverityBadge";
import React, { useState } from "react";
import { useParams } from "react-router-dom";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Progress } from "../components/ui/progress";
import { Textarea } from "../components/ui/textarea";

function AssetDiagnosticsSection0() {
  const [ack,setAck]=useState(false);
  const [comparing,setComparing]=useState(false);
  return (
    <section className="space-y-4"><AssetContextNavigation/><div className="flex flex-wrap items-center justify-between gap-3"><div><div className="flex items-center gap-2"><h1 className="text-2xl font-semibold">Diagnostics & Failure Fingerprints</h1><SeverityBadge severity={ack?"healthy":"critical"} label={ack?"Acknowledged":"INC-24018"}/></div><p className="text-sm text-muted-foreground">P-204A · Outboard bearing{comparing?" · Baseline overlay active":""}</p></div><div className="flex gap-2"><Button variant={comparing?"default":"outline"} onClick={()=>setComparing(!comparing)}>{comparing?"Hide baseline":"Compare baseline"}</Button><Button onClick={()=>setAck(true)} disabled={ack}>{ack?"Acknowledged":"Acknowledge"}</Button></div></div></section>
  );
}

function AssetDiagnosticsSection1() {
  return (
    <section className="grid gap-3 lg:grid-cols-2"><Card><CardHeader><CardTitle className="text-base">Failure mode classifier</CardTitle></CardHeader><CardContent className="space-y-4">{[{n:"Bearing outer race",v:87},{n:"Misalignment",v:41},{n:"Unbalance",v:24},{n:"Cavitation",v:8}].map((m)=><div key={m.n}><div className="mb-1 flex justify-between text-sm"><span>{m.n}</span><span className="font-mono">{m.v}%</span></div><Progress value={m.v}/></div>)}</CardContent></Card><ExplainabilityEvidence/></section>
  );
}

function AssetDiagnosticsSection2() {
  const [finding,setFinding]=useState("Outer-race bearing defect evidenced by BPFO sidebands and rising envelope energy.");
  const [saved,setSaved]=useState(false);
  return (
    <section className="grid gap-3 lg:grid-cols-[1fr_340px]"><Card><CardHeader><CardTitle className="text-base">Diagnostic finding</CardTitle></CardHeader><CardContent className="space-y-3"><Textarea value={finding} onChange={(e)=>setFinding(e.target.value)} rows={6}/><Button onClick={()=>setSaved(true)}>{saved?"Finding saved":"Save engineering finding"}</Button></CardContent></Card><Card><CardHeader><CardTitle className="text-base">Audit trail</CardTitle></CardHeader><CardContent className="space-y-3 text-sm"><p><span className="font-mono text-muted-foreground">09:42</span> Incident opened</p><p><span className="font-mono text-muted-foreground">09:47</span> Baseline compared</p><p><span className="font-mono text-muted-foreground">10:03</span> Engineer review assigned</p></CardContent></Card></section>
  );
}

export default function AssetDiagnostics() {
  return (
    <div className="w-full min-w-0 overflow-x-hidden">
      <div className="flex flex-col gap-4 w-full min-w-0">
        <AssetDiagnosticsSection0 />
        <AssetDiagnosticsSection1 />
        <AssetDiagnosticsSection2 />
      </div>
    </div>
  );
}
