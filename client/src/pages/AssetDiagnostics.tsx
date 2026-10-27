import { AssetContextNavigation } from "../components/AssetContextNavigation";
import { ExplainabilityEvidence } from "../components/ExplainabilityEvidence";
import { SeverityBadge } from "../components/SeverityBadge";
import React, { useState } from "react";
import { useParams } from "react-router-dom";
import { useModelIndex } from "@rhino-dev/rhino-react";
import { assetRecordId, useAssetByTag } from "../hooks/useAssetByTag";
import { useAcknowledgeIncident, useAssetIncidentContext, useSignOffIncident } from "../hooks/useApiQueries";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Progress } from "../components/ui/progress";
import { Textarea } from "../components/ui/textarea";

function AssetDiagnosticsSection0() {
  const {assetId="P-204A"}=useParams();
  const [ack,setAck]=useState(false);
  const [comparing,setComparing]=useState(false);
  const { asset, assetPk, incident }=useAssetIncidentContext(assetId);
  const acknowledge = useAcknowledgeIncident();
  const isAcknowledged = ack || incident?.status === "Investigating" || incident?.status === "Acknowledged";
  // Comparing overlays the incumbent baseline, so it is read on demand.
  const { data: baselineResponse } = useModelIndex("model_baselines", { filters: { asset_id: assetPk, is_active: true }, perPage: 1 }, { enabled: Boolean(assetPk) && comparing });
  const baseline = baselineResponse?.data?.[0] ?? null;
  return (
    <section className="space-y-4"><AssetContextNavigation/><div className="flex flex-wrap items-center justify-between gap-3"><div><div className="flex items-center gap-2"><h1 className="text-2xl font-semibold">Diagnostics & Failure Fingerprints</h1><SeverityBadge severity={isAcknowledged?"healthy":"critical"} label={isAcknowledged?"Acknowledged":(incident?.incident_code ?? "Incident")}/></div><p className="text-sm text-muted-foreground">{asset?.asset_tag ?? assetId} · {asset?.bearing_type ?? "Rotating equipment"}{comparing?(baseline?" · Baseline overlay active":" · No active baseline"):""}</p></div><div className="flex gap-2"><Button variant={comparing?"default":"outline"} onClick={()=>setComparing(!comparing)}>{comparing?"Hide baseline":"Compare baseline"}</Button><Button onClick={()=>{setAck(true); if(incident?.id) acknowledge.mutate(incident.id);}} disabled={isAcknowledged}>{isAcknowledged?"Acknowledged":"Acknowledge"}</Button></div></div></section>
  );
}

function AssetDiagnosticsSection1() {
  const {assetId="P-204A"}=useParams();
  const { asset } = useAssetByTag(assetId);
  const assetPk = assetRecordId(asset);
  const { data: assessmentResponse } = useModelIndex("failure_mode_assessments", { filters: { asset_id: assetPk }, sort: "-probability", perPage: 20 }, { enabled: Boolean(assetPk) });
  const assessments = assessmentResponse?.data ?? [];
  const modes = assessments.map((row) => ({ n: row.failure_mode_name ?? row.marker_label ?? "Failure mode", v: Math.round(row.probability ?? 0) }));
  const evidence = assessments.slice(0, 3).map((row) => ({ label: row.failure_mode_name ?? row.marker_label ?? "Evidence", value: Math.round((row.match_score ?? 0) * 100) }));
  return (
    <section className="grid gap-3 lg:grid-cols-2"><Card><CardHeader><CardTitle className="text-base">Failure mode classifier</CardTitle></CardHeader><CardContent className="space-y-4">{modes.map((m)=><div key={m.n}><div className="mb-1 flex justify-between text-sm"><span>{m.n}</span><span className="font-mono">{m.v}%</span></div><Progress value={m.v}/></div>)}</CardContent></Card><ExplainabilityEvidence evidence={evidence}/></section>
  );
}

function AssetDiagnosticsSection2() {
  const {assetId="P-204A"}=useParams();
  const { incident }=useAssetIncidentContext(assetId);
  const [draft,setDraft]=useState("");
  const [saved,setSaved]=useState(false);
  const finding = draft || incident?.root_cause || incident?.evidence_summary || "";
  const signOff = useSignOffIncident();
  const { data: auditResponse } = useModelIndex("security_audit_events", { search: incident?.incident_code ?? undefined, sort: "-recorded_at", perPage: 6 }, { enabled: Boolean(incident?.incident_code) });
  const auditTrail = (auditResponse?.data ?? []).map((event) => ({
    time: event.recorded_at ? new Date(event.recorded_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }) : "—",
    text: event.action_type ? `${event.action_type} ${event.entity_affected ?? ""}`.trim() : "Event recorded",
  }));
  return (
    <section className="grid gap-3 lg:grid-cols-[1fr_340px]"><Card><CardHeader><CardTitle className="text-base">Diagnostic finding</CardTitle></CardHeader><CardContent className="space-y-3"><Textarea value={finding} onChange={(e)=>setDraft(e.target.value)} rows={6}/><Button onClick={()=>{setSaved(true); if(incident?.id) signOff.mutate({ id: incident.id, finding: { root_cause: finding, evidence_summary: incident?.evidence_summary ?? finding, finding_status: "Signed Off" } });}}>{saved?"Finding saved":"Save engineering finding"}</Button></CardContent></Card><Card><CardHeader><CardTitle className="text-base">Audit trail</CardTitle></CardHeader><CardContent className="space-y-3 text-sm">{auditTrail.length ? auditTrail.map((entry)=><p key={`${entry.time}-${entry.text}`}><span className="font-mono text-muted-foreground">{entry.time}</span> {entry.text}</p>) : <p className="text-muted-foreground">No audit evidence recorded for this incident yet.</p>}</CardContent></Card></section>
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
