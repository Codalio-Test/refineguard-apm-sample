import { SeverityBadge } from "../components/SeverityBadge";
import React, { useState } from "react";
import { useModelIndex } from "@rhino-dev/rhino-react";
import { useConnectorTest } from "../hooks/useApiQueries";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Input } from "../components/ui/input";
import { Progress } from "../components/ui/progress";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../components/ui/table";

function HistorianConnectionsSection0() {
  const { data: connectorResponse } = useModelIndex("historian_connectors", { perPage: 20 });
  const connectors = connectorResponse?.data ?? [];
  const bufferTotal = connectors.reduce((total, connector) => total + (connector.buffer_depth ?? 0), 0);
  const backfillPending = connectors.reduce((total, connector) => total + Math.max((connector.backfill_total ?? 0) - (connector.backfill_committed ?? 0), 0), 0);
  const worstLatency = connectors.reduce((worst, connector) => Math.max(worst, connector.poll_latency_ms ?? 0), 0);
  const metrics = [
    ["Connected", String(connectors.filter((connector) => connector.status === "Connected").length)],
    ["Degraded", String(connectors.filter((connector) => connector.severity === "warning" || connector.severity === "critical").length)],
    ["Polling latency", `${worstLatency}ms`],
    ["Buffer depth", bufferTotal >= 1000 ? `${(bufferTotal / 1000).toFixed(1)}k` : String(bufferTotal)],
    ["Backfill queue", String(backfillPending)],
  ];
  return (
    <section className="space-y-4"><h1 className="text-2xl font-semibold">Historian Connections</h1><div className="grid grid-cols-2 gap-2 md:grid-cols-5">{metrics.map((m)=><Card key={m[0]}><CardContent className="p-4"><p className="text-xs text-muted-foreground">{m[0]}</p><p className="font-mono text-xl">{m[1]}</p></CardContent></Card>)}</div></section>
  );
}

function HistorianConnectionsSection1() {
  const { data: connectorResponse } = useModelIndex("historian_connectors", { perPage: 20 });
  // One render clock, seeded lazily: "seconds since last heartbeat" is derived
  // from it rather than from an impure call in the render body.
  const [now] = useState(() => Date.now());
  const rows = (connectorResponse?.data ?? []).map((connector) => [
    connector.severity ?? "info",
    connector.connector_name ?? "—",
    connector.protocol_type ?? "—",
    connector.endpoint_url ?? connector.server_address ?? "—",
    connector.poll_latency_ms == null ? "—" : `${connector.poll_latency_ms}ms`,
    String(connector.buffer_depth ?? 0),
    connector.last_heartbeat ? `${Math.max(Math.round((now - new Date(connector.last_heartbeat).getTime()) / 1000), 0)}s` : "—",
  ]);
  return (
    <section className="overflow-x-auto rounded-lg border bg-card"><Table><TableHeader><TableRow>{["State","Connector","Protocol","Endpoint","Latency","Buffer","Last poll"].map((h)=><TableHead key={h}>{h}</TableHead>)}</TableRow></TableHeader><TableBody>{rows.map((r)=><TableRow key={r[1]}>{r.map((c,i)=><TableCell key={`${r[1]}-${i}`}>{i===0?<SeverityBadge severity={c}/>:c}</TableCell>)}</TableRow>)}</TableBody></Table></section>
  );
}

function HistorianConnectionsSection2() {
  const { data: connectorResponse } = useModelIndex("historian_connectors", { perPage: 20 });
  const connector = connectorResponse?.data?.[0] ?? null;
  const test = useConnectorTest();
  const [saved,setSaved]=useState(false);
  const [endpoint,setEndpoint]=useState("");
  const [intervalSeconds,setIntervalSeconds]=useState("");
  const backfillCommitted = connector?.backfill_committed ?? 0;
  const backfillTotal = connector?.backfill_total ?? 0;
  const backfillPercent = backfillTotal > 0 ? Math.round((backfillCommitted / backfillTotal) * 100) : 0;
  // The probe persists endpoint + polling schedule and records latency/heartbeat.
  const testAndSave=()=>{
    if(!connector?.id) return;
    setSaved(false);
    const parsedInterval = Number(intervalSeconds.replace(/[^0-9]/g, ""));
    test.mutate(
      {
        id: connector.id,
        endpoint_url: endpoint || connector.endpoint_url,
        polling_interval_seconds: parsedInterval > 0 ? parsedInterval : connector.polling_interval_seconds,
      },
      { onSuccess: () => setSaved(true) },
    );
  };
  return (
    <section className="grid gap-3 lg:grid-cols-2"><Card><CardHeader><CardTitle className="text-base">Connector configuration</CardTitle></CardHeader><CardContent className="space-y-3"><Input value={endpoint} onChange={(e)=>{setEndpoint(e.target.value); setSaved(false);}} placeholder={connector?.endpoint_url ?? "https://pi01.ot.local/piwebapi"}/><Input value={intervalSeconds} onChange={(e)=>{setIntervalSeconds(e.target.value); setSaved(false);}} placeholder={connector?.polling_interval_seconds ? `${connector.polling_interval_seconds} seconds` : "5 seconds"}/><Button onClick={testAndSave} disabled={!connector?.id || test.isPending}>{saved?"Connection verified":test.isPending?"Testing…":"Test and save"}</Button></CardContent></Card><Card><CardHeader><CardTitle className="text-base">Buffer backfill</CardTitle></CardHeader><CardContent><Progress value={backfillPercent}/><p className="mt-3 font-mono text-xs text-muted-foreground">{backfillCommitted.toLocaleString()} / {backfillTotal.toLocaleString()} samples committed</p></CardContent></Card></section>
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
