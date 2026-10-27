import React, { useState } from "react";
import { useModelIndex } from "@rhino-dev/rhino-react";
import { useRecordAction } from "../hooks/useApiQueries";

// The promotion gates the design draws, keyed by their `gates_json` names.
const GATE_LABELS: Record<string, string> = { golden_run_provenance: "Golden run provenance", no_critical_regression: "No critical regression", specialist_sign_off: "Specialist sign-off", rollback_snapshot: "Rollback snapshot" };
const asPercent=(value?: number)=>value==null?"\u2014":`${value<=1?(value*100).toFixed(1):value}%`;
const asDays=(value?: number)=>value==null?"\u2014":`${value} d`;
const asNumber=(value?: number)=>value==null?"\u2014":String(value);
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Checkbox } from "../components/ui/checkbox";

function ModelEvaluationSection0() {
  const [status,setStatus]=useState("");
  const { data: baselineResponse } = useModelIndex("model_baselines", { sort: "-model_version", perPage: 50 });
  const baselines = baselineResponse?.data ?? [];
  const candidate = baselines.find((row) => (row.status ?? "").toLowerCase() !== "production") ?? baselines[0] ?? null;
  const production = baselines.find((row) => (row.status ?? "").toLowerCase() === "production") ?? null;
  const promote = useRecordAction('/model_baselines', 'promote', 'model_baselines');
  const exported = status === "Evidence package exported";
  const exportEvidence = () => {
    const blob = new Blob(
      [JSON.stringify({ model_version: candidate?.model_version, algorithm_type: candidate?.algorithm_type, accuracy_metrics: candidate?.accuracy_metrics_json, gates: candidate?.gates_json, training_window_start: candidate?.training_window_start, training_window_end: candidate?.training_window_end }, null, 2)],
      { type: "application/json" },
    );
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `${candidate?.model_version ?? "model"}-evidence.json`;
    anchor.click();
    URL.revokeObjectURL(url);
    setStatus("Evidence package exported");
  };
  const subtitle = status || (candidate && production ? `Candidate ${candidate.model_version} versus production ${production.model_version}` : "No candidate baseline is awaiting evaluation");
  return (
    <section className="flex flex-wrap items-center gap-2"><div className="mr-auto"><h1 className="text-2xl font-semibold">Model Evaluation</h1><p className="text-sm text-muted-foreground">{subtitle}</p></div><Button variant="outline" onClick={exportEvidence} disabled={!candidate}>{exported?"Evidence exported":"Export evidence"}</Button><Button onClick={()=>candidate?.id&&promote.mutate({ id: candidate.id })} disabled={!candidate?.id||promote.isPending}>{promote.isSuccess?"Promotion approval recorded":"Approve promotion"}</Button></section>
  );
}

function ModelEvaluationSection1() {
  const { data: baselineResponse } = useModelIndex("model_baselines", { sort: "-model_version", perPage: 50 });
  const baselines = baselineResponse?.data ?? [];
  const candidate = baselines.find((row) => (row.status ?? "").toLowerCase() !== "production") ?? baselines[0] ?? null;
  const scores = candidate?.accuracy_metrics_json ?? {};
  const metrics = [
    ["Precision", asPercent(scores.precision)],
    ["Recall", asPercent(scores.recall)],
    ["False alarms", asPercent(scores.false_alarms)],
    ["Lead time", asDays(scores.lead_time_days)],
    ["Drift", asNumber(scores.drift)],
    ["Coverage", asPercent(scores.coverage)],
  ];
  const series = Object.values(scores).filter((value): value is number => typeof value === "number");
  const backtestPoints = series.length > 1
    ? series.map((value, index) => `${((index / (series.length - 1)) * 800).toFixed(1)},${(160 - Math.min(Math.max(value <= 1 ? value * 100 : value, 0), 100) * 1.4).toFixed(1)}`).join(" ")
    : "";
  return (
    <section className="space-y-3"><div className="grid grid-cols-2 gap-2 md:grid-cols-3 xl:grid-cols-6">{metrics.map((m)=><Card key={m[0]}><CardContent className="p-4"><p className="text-xs text-muted-foreground">{m[0]}</p><p className="mt-1 font-mono text-2xl">{m[1]}</p></CardContent></Card>)}</div><Card><CardHeader><CardTitle className="text-base">Health backtest</CardTitle></CardHeader><CardContent><svg viewBox="0 0 800 160" className="h-52 w-full text-primary"><polyline points={backtestPoints} fill="none" stroke="currentColor" strokeWidth="3"/></svg></CardContent></Card></section>
  );
}

function ModelEvaluationSection2() {
  const { data: baselineResponse } = useModelIndex("model_baselines", { sort: "-model_version", perPage: 50 });
  const baselines = baselineResponse?.data ?? [];
  const candidate = baselines.find((row) => (row.status ?? "").toLowerCase() !== "production") ?? baselines[0] ?? null;
  const gates = Object.entries(candidate?.gates_json ?? {}).map(([key, satisfied]) => ({ label: GATE_LABELS[key] ?? key.replace(/_/g, " "), satisfied: Boolean(satisfied) }));
  const [confirmed,setConfirmed]=useState<string[]>([]);
  const promote = useRecordAction('/model_baselines', 'promote', 'model_baselines');
  const promoted = promote.isSuccess || (candidate?.status ?? "").toLowerCase() === "production";
  const allGatesPass = gates.length > 0 && gates.every((gate) => gate.satisfied || confirmed.includes(gate.label));
  return (
    <section className="grid gap-3 lg:grid-cols-2"><Card><CardHeader><CardTitle className="text-base">Evaluation gates</CardTitle></CardHeader><CardContent className="space-y-3">{gates.map((gate)=><label key={gate.label} className="flex items-center gap-3 text-sm"><Checkbox checked={gate.satisfied||confirmed.includes(gate.label)} onCheckedChange={()=>setConfirmed((c)=>c.includes(gate.label)?c.filter((x)=>x!==gate.label):[...c,gate.label])}/>{gate.label}</label>)}<Button disabled={!allGatesPass||promoted||!candidate?.id} onClick={()=>candidate?.id&&promote.mutate({ id: candidate.id })}>{promoted?"Candidate promoted":"Promote candidate"}</Button></CardContent></Card><Card><CardHeader><CardTitle className="text-base">Version history</CardTitle></CardHeader><CardContent className="space-y-3 text-sm">{baselines.map((row)=><p key={row.id}><span className="font-mono">{row.model_version}</span> · {row.status ?? "—"} · {row.approved_by_name ?? "Unassigned"}</p>)}</CardContent></Card></section>
  );
}

export default function ModelEvaluation() {
  return (
    <div className="w-full min-w-0 overflow-x-hidden">
      <div className="flex flex-col gap-4 w-full min-w-0">
        <ModelEvaluationSection0 />
        <ModelEvaluationSection1 />
        <ModelEvaluationSection2 />
      </div>
    </div>
  );
}
