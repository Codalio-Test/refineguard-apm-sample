import { AssetContextNavigation } from "../components/AssetContextNavigation";
import { SeverityBadge } from "../components/SeverityBadge";
import { TelemetryValue } from "../components/TelemetryValue";
import React, { useState } from "react";
import { useParams } from "react-router-dom";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Progress } from "../components/ui/progress";
import { Table, TableBody, TableCell, TableRow } from "../components/ui/table";

function AssetHealthSummarySection0() {
  const {assetId="P-204A"}=useParams();
  const [acknowledged,setAcknowledged]=useState(false);
  return (
    <section className="space-y-4"><AssetContextNavigation/><div className="flex flex-wrap items-center justify-between gap-3"><div><p className="font-mono text-xl font-semibold">{assetId}</p><p className="text-sm text-muted-foreground">CDU-1 · Charge pump train A</p></div><div className="flex items-center gap-2"><SeverityBadge severity={acknowledged?"healthy":"critical"} label={acknowledged?"Acknowledged":"Alarm"}/><Button onClick={()=>setAcknowledged(true)} disabled={acknowledged}>{acknowledged?"Acknowledged":"Acknowledge"}</Button></div></div></section>
  );
}

function AssetHealthSummarySection1() {
  return (
    <section className="space-y-3"><div className="grid gap-3 md:grid-cols-[280px_1fr]"><Card><CardHeader><CardTitle className="text-base">Health index</CardTitle></CardHeader><CardContent><p className="font-mono text-5xl font-semibold">28</p><Progress value={28} className="mt-4"/><p className="mt-2 text-xs text-muted-foreground">↓ 19 points from baseline</p></CardContent></Card><Card><CardHeader><CardTitle className="text-base">Operating envelope</CardTitle></CardHeader><CardContent className="grid grid-cols-2 gap-5 md:grid-cols-3"><TelemetryValue label="RMS velocity" value="8.42" unit="mm/s" trend="up" detail="+32%"/><TelemetryValue label="Bearing temp" value="96" unit="°C" trend="up" detail="+14°C"/><TelemetryValue label="Motor current" value="112" unit="A" trend="stable" detail="normal"/></CardContent></Card></div></section>
  );
}

function AssetHealthSummarySection2() {
  return (
    <section className="grid gap-3 lg:grid-cols-[1fr_340px]"><Card><CardHeader><CardTitle className="text-base">Anomaly attribution</CardTitle></CardHeader><CardContent className="space-y-4"><p className="text-sm">78% Outboard Bearing 1X harmonic surge</p><Progress value={78}/><p className="text-sm">22% DE Bearing RTD thermal drift</p><Progress value={22}/></CardContent></Card><Card><CardHeader><CardTitle className="text-base">Envelope checks</CardTitle></CardHeader><CardContent><Table><TableBody>{[["Vibration","8.42","Alarm"],["Temperature","96°C","High"],["Pressure","12.4 bar","Normal"]].map((r)=><TableRow key={r[0]}>{r.map((c)=><TableCell key={c} className="text-xs">{c}</TableCell>)}</TableRow>)}</TableBody></Table></CardContent></Card></section>
  );
}

export default function AssetHealthSummary() {
  return (
    <div className="w-full min-w-0 overflow-x-hidden">
      <div className="flex flex-col gap-4 w-full min-w-0">
        <AssetHealthSummarySection0 />
        <AssetHealthSummarySection1 />
        <AssetHealthSummarySection2 />
      </div>
    </div>
  );
}
