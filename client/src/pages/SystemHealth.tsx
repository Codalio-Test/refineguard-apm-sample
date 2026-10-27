import { SeverityBadge } from "../components/SeverityBadge";
import React from "react";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { useSystemHealth } from "../hooks/useApiQueries";
import { Progress } from "../components/ui/progress";

/** A value the process did not actually measure is rendered as "Not measured". */
const NOT_MEASURED = "Not measured";

function serviceSeverity(status: string): string {
  if (status === "Running") return "healthy";
  if (status === "Degraded") return "warning";
  return "info";
}

function SystemHealthSection0() {
  const { data: health } = useSystemHealth();
  return (
    <section className="space-y-4"><h1 className="text-2xl font-semibold">System Health</h1><div className="grid grid-cols-2 gap-2 md:grid-cols-3 xl:grid-cols-6">{(health?.metrics ?? []).map((metric)=><Card key={metric.name}><CardContent className="p-4"><p className="text-xs text-muted-foreground">{metric.name}</p><p className="font-mono text-xl">{metric.value ?? NOT_MEASURED}</p></CardContent></Card>)}</div></section>
  );
}

function SystemHealthSection1() {
  const { data: health } = useSystemHealth();
  const measuredVolumes = (health?.storage ?? []).filter(
    (volume) => volume.status === "measured" && volume.percent != null,
  );
  const storageAverage = measuredVolumes.length
    ? Math.round(measuredVolumes.reduce((total, volume) => total + Number(volume.percent), 0) / measuredVolumes.length)
    : null;
  const backupStatus = health?.backup?.status ?? NOT_MEASURED;
  return (
    <section className="grid gap-3 lg:grid-cols-[1fr_360px]"><Card><CardHeader><CardTitle className="text-base">Service health</CardTitle></CardHeader><CardContent className="space-y-3">{(health?.services ?? []).map((service)=><div key={service.name} className="flex items-center justify-between rounded border p-2 text-sm"><span>{service.name}</span><SeverityBadge severity={serviceSeverity(service.status)} label={service.status}/></div>)}</CardContent></Card><Card><CardHeader><CardTitle className="text-base">Resource trend</CardTitle></CardHeader><CardContent>{storageAverage == null ? <p className="text-sm text-muted-foreground">{NOT_MEASURED}</p> : <Progress value={storageAverage}/>}<p className="mt-3 text-xs text-muted-foreground">{storageAverage == null ? "Disk utilisation" : `Mean volume utilisation ${storageAverage}%`} · backups {backupStatus.toLowerCase()}</p></CardContent></Card></section>
  );
}

function SystemHealthSection2() {
  const { data: health } = useSystemHealth();
  const storage = health?.storage ?? [];
  return (
    <section className="grid gap-3 lg:grid-cols-2"><Card><CardHeader><CardTitle className="text-base">Storage</CardTitle></CardHeader><CardContent className="space-y-4">{storage.map((volume)=><div key={volume.name}><div className="mb-1 flex justify-between text-xs"><span>{volume.name}</span><span>{volume.percent == null ? NOT_MEASURED : `${volume.percent}%`}</span></div>{volume.percent != null && <Progress value={Number(volume.percent)} className={Number(volume.percent) > 80 ? "ring-1 ring-destructive" : undefined} />}</div>)}</CardContent></Card><Card><CardHeader><CardTitle className="text-base">Platform events</CardTitle></CardHeader><CardContent className="space-y-2 font-mono text-xs text-muted-foreground">{(health?.events ?? []).length ? (health?.events ?? []).map((event)=><p key={event}>{event}</p>) : <p>{NOT_MEASURED}</p>}</CardContent></Card></section>
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
