import React, { useState } from "react";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Checkbox } from "../components/ui/checkbox";

function ModelEvaluationSection0() {
  const [status,setStatus]=useState("Candidate v3.8 versus production v3.7");
  return (
    <section className="flex flex-wrap items-center gap-2"><div className="mr-auto"><h1 className="text-2xl font-semibold">Model Evaluation</h1><p className="text-sm text-muted-foreground">{status}</p></div><Button variant="outline" onClick={()=>setStatus("Evidence package exported")}>Export evidence</Button><Button onClick={()=>setStatus("Promotion approval recorded")}>Approve promotion</Button></section>
  );
}

function ModelEvaluationSection1() {
  return (
    <section className="space-y-3"><div className="grid grid-cols-2 gap-2 md:grid-cols-3 xl:grid-cols-6">{[["Precision","94.2%"],["Recall","91.8%"],["False alarms","1.6%"],["Lead time","18.4 d"],["Drift","0.07"],["Coverage","98.9%"]].map((m)=><Card key={m[0]}><CardContent className="p-4"><p className="text-xs text-muted-foreground">{m[0]}</p><p className="mt-1 font-mono text-2xl">{m[1]}</p></CardContent></Card>)}</div><Card><CardHeader><CardTitle className="text-base">Health backtest</CardTitle></CardHeader><CardContent><svg viewBox="0 0 800 160" className="h-52 w-full text-primary"><polyline points="0,130 100,125 200,118 300,120 400,92 500,100 600,65 700,50 800,28" fill="none" stroke="currentColor" strokeWidth="3"/></svg></CardContent></Card></section>
  );
}

function ModelEvaluationSection2() {
  const gates=["Golden run provenance","No critical regression","Specialist sign-off","Rollback snapshot"];
  const [checked,setChecked]=useState(gates.slice(0,2));
  const [promoted,setPromoted]=useState(false);
  return (
    <section className="grid gap-3 lg:grid-cols-2"><Card><CardHeader><CardTitle className="text-base">Evaluation gates</CardTitle></CardHeader><CardContent className="space-y-3">{gates.map((g)=><label key={g} className="flex items-center gap-3 text-sm"><Checkbox checked={checked.includes(g)} onCheckedChange={()=>setChecked((c)=>c.includes(g)?c.filter((x)=>x!==g):[...c,g])}/>{g}</label>)}<Button disabled={checked.length<gates.length||promoted} onClick={()=>setPromoted(true)}>{promoted?"Candidate promoted":"Promote candidate"}</Button></CardContent></Card><Card><CardHeader><CardTitle className="text-base">Version history</CardTitle></CardHeader><CardContent className="space-y-3 text-sm"><p><span className="font-mono">v3.8</span> · Candidate · Pending approval</p><p><span className="font-mono">v3.7</span> · Production · M. Chen</p><p><span className="font-mono">v3.6</span> · Archived · S. Patel</p></CardContent></Card></section>
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
