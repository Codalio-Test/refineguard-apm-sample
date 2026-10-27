import { SeverityBadge } from "../components/SeverityBadge";
import React from "react";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Progress } from "../components/ui/progress";

function SystemHealthSection0() {
  return (
    <section className="space-y-4"><h1 className="text-2xl font-semibold">System Health</h1><div className="grid grid-cols-2 gap-2 md:grid-cols-3 xl:grid-cols-6">{[["Local DB","OK"],["API latency","42ms"],["Ingestion","18.4k/s"],["Disk used","61%"],["Workers","8/8"],["Clock drift","4ms"]].map((m)=><Card key={m[0]}><CardContent className="p-4"><p className="text-xs text-muted-foreground">{m[0]}</p><p className="font-mono text-xl">{m[1]}</p></CardContent></Card>)}</div></section>
  );
}

function SystemHealthSection1() {
  return (
    <section className="grid gap-3 lg:grid-cols-[1fr_360px]"><Card><CardHeader><CardTitle className="text-base">Service health</CardTitle></CardHeader><CardContent className="space-y-3">{["Ingestion gateway","Time-series database","Diagnostic engine","Model worker","CMMS bridge","LDAP"].map((s)=><div key={s} className="flex items-center justify-between rounded border p-2 text-sm"><span>{s}</span><SeverityBadge severity="healthy" label="Online"/></div>)}</CardContent></Card><Card><CardHeader><CardTitle className="text-base">Resource trend</CardTitle></CardHeader><CardContent><Progress value={58}/><p className="mt-3 text-xs text-muted-foreground">CPU 58% · Memory 64% · I/O normal</p></CardContent></Card></section>
  );
}

function SystemHealthSection2() {
  return (
    <section className="grid gap-3 lg:grid-cols-2"><Card><CardHeader><CardTitle className="text-base">Storage</CardTitle></CardHeader><CardContent className="space-y-4">{[["Historian cache",44],["Telemetry store",61],["Model artifacts",32],["Audit archive",72]].map((v)=><div key={v[0]}><div className="mb-1 flex justify-between text-xs"><span>{v[0]}</span><span>{v[1]}%</span></div><Progress value={Number(v[1])}/></div>)}</CardContent></Card><Card><CardHeader><CardTitle className="text-base">Platform events</CardTitle></CardHeader><CardContent className="space-y-2 font-mono text-xs text-muted-foreground"><p>10:42 worker-04 heartbeat restored</p><p>10:38 PI buffer batch committed</p><p>10:31 LDAP certificate verified</p></CardContent></Card></section>
  );
}

export default function SystemHealth() {
  return (
    <div className="w-full min-w-0 overflow-x-hidden">
      <div className="flex flex-col gap-4 w-full min-w-0">
        <SystemHealthSection0 />
        <SystemHealthSection1 />
        <SystemHealthSection2 />
      </div>
    </div>
  );
}
