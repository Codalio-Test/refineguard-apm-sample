import { AssetContextNavigation } from "../components/AssetContextNavigation";
import { SeverityBadge } from "../components/SeverityBadge";
import { TelemetryValue } from "../components/TelemetryValue";
import React, { useState } from "react";
import { useParams } from "react-router-dom";
import { useModelIndex } from "@rhino-dev/rhino-react";
import { useAssetByTag } from "../hooks/useAssetByTag";
import type { AssetHealthIndex } from "../types/rhino";
import { useAcknowledgeIncident, useAssetIncidentContext } from "../hooks/useApiQueries";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Progress } from "../components/ui/progress";
import { Table, TableBody, TableCell, TableRow } from "../components/ui/table";

function AssetHealthSummarySection0() {
  const {assetId="P-204A"}=useParams();
  const [acknowledged,setAcknowledged]=useState(false);
  const { asset, incident }=useAssetIncidentContext(assetId);
  const acknowledge = useAcknowledgeIncident();
  const isAcknowledged = acknowledged || incident?.status === "Investigating" || incident?.status === "Acknowledged";
  return (
    <section className="space-y-4"><AssetContextNavigation/><div className="flex flex-wrap items-center justify-between gap-3"><div><p className="font-mono text-xl font-semibold">{assetId}</p><p className="text-sm text-muted-foreground">{asset?.unit ?? "—"} · {asset?.asset_name ?? "—"}</p></div><div className="flex items-center gap-2"><SeverityBadge severity={isAcknowledged?"healthy":"critical"} label={isAcknowledged?"Acknowledged":(incident?.incident_code ?? "Alarm")}/><Button onClick={()=>{setAcknowledged(true); if(incident?.id) acknowledge.mutate(incident.id);}} disabled={isAcknowledged}>{isAcknowledged?"Acknowledged":"Acknowledge"}</Button></div></div></section>
  );
}

function AssetHealthSummarySection1() {
  const {assetId="P-204A"}=useParams();
  const { asset } = useAssetByTag(assetId);
  const health = asset?.health ?? asset?.health_index ?? null;
  const healthDelta = asset?.health_index_delta ?? null;
  const rms = asset?.rms ?? (asset?.rms_velocity_mms == null ? null : String(asset.rms_velocity_mms));
  const rmsDelta = asset?.rms_velocity_delta_pct ?? null;
  const temp = asset?.temp ?? (asset?.bearing_temp_c == null ? null : String(asset.bearing_temp_c));
  const tempDelta = asset?.bearing_temp_delta_c ?? null;
  const amps = asset?.motor_current_a ?? null;
  return (
    <section className="space-y-3"><div className="grid gap-3 md:grid-cols-[280px_1fr]"><Card><CardHeader><CardTitle className="text-base">Health index</CardTitle></CardHeader><CardContent><p className="font-mono text-5xl font-semibold">{health ?? "—"}</p><Progress value={health ?? 0} className="mt-4"/><p className="mt-2 text-xs text-muted-foreground">{healthDelta == null ? "No baseline comparison available" : `${healthDelta < 0 ? "↓" : "↑"} ${Math.abs(healthDelta)} points from baseline`}</p></CardContent></Card><Card><CardHeader><CardTitle className="text-base">Operating envelope</CardTitle></CardHeader><CardContent className="grid grid-cols-2 gap-5 md:grid-cols-3"><TelemetryValue label="RMS velocity" value={rms ?? "—"} unit="mm/s" trend={rmsDelta == null ? "stable" : rmsDelta > 0 ? "up" : "down"} detail={rmsDelta == null ? "no baseline" : `${rmsDelta > 0 ? "+" : ""}${rmsDelta}%`}/><TelemetryValue label="Bearing temp" value={temp ?? "—"} unit="°C" trend={tempDelta == null ? "stable" : tempDelta > 0 ? "up" : "down"} detail={tempDelta == null ? "no baseline" : `${tempDelta > 0 ? "+" : ""}${tempDelta}°C`}/><TelemetryValue label="Motor current" value={amps ?? "—"} unit="A" trend="stable" detail="normal"/></CardContent></Card></div></section>
  );
}

function AssetHealthSummarySection2() {
  const {assetId="P-204A"}=useParams();
  const { assetPk }=useAssetIncidentContext(assetId);
  const { data: indexResponse } = useModelIndex<AssetHealthIndex>("asset_health_indices", { filters: { asset_id: assetPk }, sort: "-calculated_at", perPage: 1 }, { enabled: Boolean(assetPk) });
  const latestIndex = indexResponse?.data?.[0] ?? null;
  const attribution = latestIndex?.attribution ?? [];
  const envelopeChecks = (latestIndex?.envelope_checks ?? []).map((check) => [check.label ?? "—", `${check.observed ?? "—"}${check.unit ? ` ${check.unit}` : ""}`, check.breached ? "Alarm" : "Normal"]);
  return (
    <section className="grid gap-3 lg:grid-cols-[1fr_340px]"><Card><CardHeader><CardTitle className="text-base">Anomaly attribution</CardTitle></CardHeader><CardContent className="space-y-4">{attribution.map((factor)=><React.Fragment key={factor.label}><p className="text-sm">{factor.percent ?? 0}% {factor.label}</p><Progress value={factor.percent ?? 0}/></React.Fragment>)}</CardContent></Card><Card><CardHeader><CardTitle className="text-base">Envelope checks</CardTitle></CardHeader><CardContent><Table><TableBody>{envelopeChecks.map((r)=><TableRow key={r[0]}>{r.map((c)=><TableCell key={c} className="text-xs">{c}</TableCell>)}</TableRow>)}</TableBody></Table></CardContent></Card></section>
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
