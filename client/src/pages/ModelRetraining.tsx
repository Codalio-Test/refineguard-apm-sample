import { SeverityBadge } from "../components/SeverityBadge";
import React, { useState } from "react";
import { useModelIndex, useModelUpdate } from "@rhino-dev/rhino-react";
import { useRecordAction } from "../hooks/useApiQueries";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Checkbox } from "../components/ui/checkbox";
import { Input } from "../components/ui/input";
import { Progress } from "../components/ui/progress";

function ModelRetrainingSection0() {
  const [mode,setMode]=useState("");
  const { data: baselineResponse } = useModelIndex("model_baselines", { perPage: 50 });
  const candidate = baselineResponse?.data?.[0] ?? null;
  const eligible = candidate?.status !== "Training";
  const subtitle = mode || (candidate ? `Asset ${candidate.asset_tag ?? "—"} · ${candidate.algorithm_type ?? "vibration baseline"}` : "No baseline is available for retraining");
  return (
    <section className="flex flex-wrap items-center gap-2"><div className="mr-auto"><h1 className="text-2xl font-semibold">Model Retraining</h1><p className="text-sm text-muted-foreground">{subtitle}</p></div><SeverityBadge severity={eligible?"healthy":"warning"} label={eligible?"Eligible":"Training"}/><Button variant="outline" onClick={()=>setMode("Baseline comparison enabled")}>Compare baseline</Button><Button onClick={()=>setMode("Training configuration ready below")}>Start retraining</Button></section>
  );
}

function ModelRetrainingSection1() {
  const { data: windowResponse } = useModelIndex("baseline_windows", { perPage: 50 });
  const windows = windowResponse?.data ?? [];
  const update = useModelUpdate("baseline_windows");
  const seriesPoints = (values: number[]) =>
    values.length > 1
      ? values.map((value, index) => `${((index / (values.length - 1)) * 500).toFixed(1)},${(180 - Math.min(Math.max(value, 0), 100) * 1.2).toFixed(1)}`).join(" ")
      : "";
  const candidatePoints = seriesPoints(windows.map((window) => window.load_percent ?? 0));
  const baselinePoints = seriesPoints(windows.map((window) => window.completeness_percent ?? 0));
  return (
    <section className="grid gap-3 lg:grid-cols-2"><Card><CardHeader><CardTitle className="text-base">Golden run selector</CardTitle></CardHeader><CardContent className="space-y-3">{windows.map((window)=><label key={window.id} className="flex items-center gap-3 rounded-md border p-3 text-sm"><Checkbox checked={Boolean(window.selected)} onCheckedChange={()=>window.id&&update.mutate({id:window.id,data:{selected:!window.selected}})}/>{window.label ?? `Window ${window.id}`}</label>)}</CardContent></Card><Card><CardHeader><CardTitle className="text-base">Baseline comparison</CardTitle></CardHeader><CardContent><svg viewBox="0 0 500 180" className="h-52 w-full text-primary"><polyline points={candidatePoints} fill="none" stroke="currentColor" strokeWidth="3"/><polyline points={baselinePoints} fill="none" stroke="currentColor" strokeWidth="2" opacity=".4"/></svg></CardContent></Card></section>
  );
}

function ModelRetrainingSection2() {
  const { data: baselineResponse } = useModelIndex("model_baselines", { perPage: 50 });
  const { data: windowResponse } = useModelIndex("baseline_windows", { perPage: 50 });
  const candidate = baselineResponse?.data?.[0] ?? null;
  const windows = windowResponse?.data ?? [];
  const train = useRecordAction('/model_baselines', 'train', 'model_baselines');
  const hyper = (candidate?.hyperparameters_json ?? {}) as Record<string, unknown>;
  const progress = train.isPending ? 45 : train.isSuccess ? 100 : candidate?.training_progress ?? 0;
  const trainingLog = train.isPending ? "[FIT] local training run started" : candidate?.training_log ?? "Awaiting local training run";
  const runLocally = () => {
    if (!candidate?.id) return;
    train.mutate({ id: candidate.id, baseline_window_ids: windows.filter((window) => window.selected && window.id).map((window) => window.id as number) });
  };
  return (
    <section className="grid gap-3 lg:grid-cols-2"><Card><CardHeader><CardTitle className="text-base">Retraining configuration</CardTitle></CardHeader><CardContent className="grid grid-cols-2 gap-3"><Input defaultValue={String(hyper.window_days ?? hyper.window ?? "")} placeholder="14 days"/><Input defaultValue={String(hyper.threshold ?? hyper.anomaly_threshold_std ?? "")} placeholder="0.02"/><Input defaultValue={String(hyper.features ?? "")} placeholder="Vibration + process"/><Input defaultValue={String(hyper.validation ?? "")} placeholder="20% validation"/><Button className="col-span-2" onClick={runLocally} disabled={!candidate?.id || train.isPending}>{train.isPending?"Training…":"Run locally"}</Button></CardContent></Card><Card><CardHeader><CardTitle className="text-base">Training run monitor</CardTitle></CardHeader><CardContent><Progress value={progress}/><p className="mt-4 font-mono text-xs text-muted-foreground">{trainingLog}</p></CardContent></Card></section>
  );
}

export default function ModelRetraining() {
  return (
    <div className="w-full min-w-0 overflow-x-hidden">
      <div className="flex flex-col gap-4 w-full min-w-0">
        <ModelRetrainingSection0 />
        <ModelRetrainingSection1 />
        <ModelRetrainingSection2 />
      </div>
    </div>
  );
}
