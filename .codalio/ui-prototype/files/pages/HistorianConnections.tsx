import { SeverityBadge } from "../components/SeverityBadge";
import React, { useState } from "react";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Input } from "../components/ui/input";
import { Progress } from "../components/ui/progress";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../components/ui/table";

function HistorianConnectionsSection0() {
  return (
    <section className="space-y-4"><h1 className="text-2xl font-semibold">Historian Connections</h1><div className="grid grid-cols-2 gap-2 md:grid-cols-5">{[["Connected","4"],["Degraded","1"],["Polling latency","380ms"],["Buffer depth","18.2k"],["Backfill queue","2"]].map((m)=><Card key={m[0]}><CardContent className="p-4"><p className="text-xs text-muted-foreground">{m[0]}</p><p className="font-mono text-xl">{m[1]}</p></CardContent></Card>)}</div></section>
  );
}

function HistorianConnectionsSection1() {
  return (
    <section className="overflow-x-auto rounded-lg border bg-card"><Table><TableHeader><TableRow>{["State","Connector","Protocol","Endpoint","Latency","Buffer","Last poll"].map((h)=><TableHead key={h}>{h}</TableHead>)}</TableRow></TableHeader><TableBody>{[["healthy","PI Primary","PI Web API","pi01.ot.local","380ms","0","8s"],["warning","PHD Backup","OPC HDA","phd02.ot.local","1.8s","18.2k","44s"]].map((r)=><TableRow key={r[1]}>{r.map((c,i)=><TableCell key={c}>{i===0?<SeverityBadge severity={c}/>:c}</TableCell>)}</TableRow>)}</TableBody></Table></section>
  );
}

function HistorianConnectionsSection2() {
  const [saved,setSaved]=useState(false);
  return (
    <section className="grid gap-3 lg:grid-cols-2"><Card><CardHeader><CardTitle className="text-base">Connector configuration</CardTitle></CardHeader><CardContent className="space-y-3"><Input defaultValue="https://pi01.ot.local/piwebapi" onChange={()=>setSaved(false)}/><Input defaultValue="5 seconds" onChange={()=>setSaved(false)}/><Button onClick={()=>setSaved(true)}>{saved?"Connection verified":"Test and save"}</Button></CardContent></Card><Card><CardHeader><CardTitle className="text-base">Buffer backfill</CardTitle></CardHeader><CardContent><Progress value={68}/><p className="mt-3 font-mono text-xs text-muted-foreground">12,402 / 18,240 samples committed</p></CardContent></Card></section>
  );
}

export default function HistorianConnections() {
  return (
    <div className="w-full min-w-0 overflow-x-hidden">
      <div className="flex flex-col gap-4 w-full min-w-0">
        <HistorianConnectionsSection0 />
        <HistorianConnectionsSection1 />
        <HistorianConnectionsSection2 />
      </div>
    </div>
  );
}
