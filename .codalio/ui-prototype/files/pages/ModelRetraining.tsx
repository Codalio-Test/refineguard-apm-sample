import { SeverityBadge } from "../components/SeverityBadge";
import React, { useState } from "react";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Checkbox } from "../components/ui/checkbox";
import { Input } from "../components/ui/input";
import { Progress } from "../components/ui/progress";

function ModelRetrainingSection0() {
  const [mode,setMode]=useState("Asset P-204A · vibration baseline");
  return (
    <section className="flex flex-wrap items-center gap-2"><div className="mr-auto"><h1 className="text-2xl font-semibold">Model Retraining</h1><p className="text-sm text-muted-foreground">{mode}</p></div><SeverityBadge severity="healthy" label="Eligible"/><Button variant="outline" onClick={()=>setMode("Baseline comparison enabled")}>Compare baseline</Button><Button onClick={()=>setMode("Training configuration ready below")}>Start retraining</Button></section>
  );
}

function ModelRetrainingSection1() {
  return (
    <section className="grid gap-3 lg:grid-cols-2"><Card><CardHeader><CardTitle className="text-base">Golden run selector</CardTitle></CardHeader><CardContent className="space-y-3">{["Apr 02 · 88% load · 99.8% complete","Apr 08 · 91% load · 99.6% complete","Apr 14 · 87% load · 100% complete"].map((r)=><label key={r} className="flex items-center gap-3 rounded-md border p-3 text-sm"><Checkbox defaultChecked/>{r}</label>)}</CardContent></Card><Card><CardHeader><CardTitle className="text-base">Baseline comparison</CardTitle></CardHeader><CardContent><svg viewBox="0 0 500 180" className="h-52 w-full text-primary"><polyline points="0,120 60,115 120,122 180,92 240,104 300,80 360,88 420,64 500,70" fill="none" stroke="currentColor" strokeWidth="3"/><polyline points="0,135 60,130 120,128 180,120 240,126 300,112 360,110 420,105 500,102" fill="none" stroke="currentColor" strokeWidth="2" opacity=".4"/></svg></CardContent></Card></section>
  );
}

function ModelRetrainingSection2() {
  const [progress,setProgress]=useState(0);
  return (
    <section className="grid gap-3 lg:grid-cols-2"><Card><CardHeader><CardTitle className="text-base">Retraining configuration</CardTitle></CardHeader><CardContent className="grid grid-cols-2 gap-3"><Input defaultValue="14 days"/><Input defaultValue="0.02"/><Input defaultValue="Vibration + process"/><Input defaultValue="20% validation"/><Button className="col-span-2" onClick={()=>setProgress(68)}>Run locally</Button></CardContent></Card><Card><CardHeader><CardTitle className="text-base">Training run monitor</CardTitle></CardHeader><CardContent><Progress value={progress}/><p className="mt-4 font-mono text-xs text-muted-foreground">{progress?"[FIT] Epoch 42 · loss 0.038 · validation queued":"Awaiting local training run"}</p></CardContent></Card></section>
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
