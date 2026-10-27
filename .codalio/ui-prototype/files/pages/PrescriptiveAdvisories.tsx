import { SeverityBadge } from "../components/SeverityBadge";
import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Input } from "../components/ui/input";
import { Progress } from "../components/ui/progress";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../components/ui/table";

function PrescriptiveAdvisoriesSection0() {
  const [filter,setFilter]=useState("Shortest RUL");
  const [query,setQuery]=useState("");
  return (
    <section className="space-y-4"><div><h1 className="text-2xl font-semibold">Prescriptive Advisories</h1><p className="text-sm text-muted-foreground">{query?`Filtering advisories by “${query}”`:"Prioritize intervention by RUL and production consequence."}</p></div><div className="flex flex-wrap gap-2"><Input className="max-w-sm" value={query} onChange={(e)=>setQuery(e.target.value)} placeholder="Search advisory or asset"/>{["State","Unit","RUL window","Shortest RUL"].map((item)=><Button key={item} variant={filter===item?"default":"outline"} onClick={()=>setFilter(item)}>{item}</Button>)}</div></section>
  );
}

function PrescriptiveAdvisoriesSection1() {
  const rows=[{asset:"P-204A",finding:"Outer race defect",rul:"6–11 d",pf:"21 d",rec:"Inspect and replace bearing",s:"critical"},{asset:"C-101B",finding:"Misalignment",rul:"18–26 d",pf:"45 d",rec:"Laser align coupling",s:"warning"}];
  const [selected,setSelected]=useState("P-204A");
  return (
    <section className="overflow-x-auto rounded-lg border border-border bg-card"><Table><TableHeader><TableRow>{["Priority","Asset","Finding","RUL window","P-F interval","Recommendation","CMMS"].map((h)=><TableHead key={h}>{h}</TableHead>)}</TableRow></TableHeader><TableBody>{rows.map((r)=><TableRow key={r.asset} onClick={()=>setSelected(r.asset)} className={selected===r.asset?"bg-muted":"cursor-pointer"}><TableCell><SeverityBadge severity={r.s}/></TableCell><TableCell className="font-mono">{r.asset}</TableCell><TableCell>{r.finding}</TableCell><TableCell>{r.rul}</TableCell><TableCell>{r.pf}</TableCell><TableCell>{r.rec}</TableCell><TableCell>Draft</TableCell></TableRow>)}</TableBody></Table></section>
  );
}

function PrescriptiveAdvisoriesSection2() {
  const navigate=useNavigate();
  return (
    <section className="grid gap-3 lg:grid-cols-[1fr_360px]"><Card><CardHeader><CardTitle className="text-base">Recommended intervention · P-204A</CardTitle></CardHeader><CardContent><ol className="list-decimal space-y-2 pl-5 text-sm text-muted-foreground"><li>Verify lubrication condition and bearing temperature.</li><li>Schedule bearing replacement within 7 days.</li><li>Inspect shaft and housing fit during outage.</li></ol><Button className="mt-5" onClick={()=>navigate("/work-orders/confirmation")}>Create work order</Button></CardContent></Card><Card><CardHeader><CardTitle className="text-base">RUL confidence</CardTitle></CardHeader><CardContent><p className="font-mono text-3xl">6–11 days</p><Progress value={72} className="mt-4"/><p className="mt-2 text-xs text-muted-foreground">Bearing lead time: 3 days · In stock</p></CardContent></Card></section>
  );
}

export default function PrescriptiveAdvisories() {
  return (
    <div className="w-full min-w-0 overflow-x-hidden">
      <div className="flex flex-col gap-4 w-full min-w-0">
        <PrescriptiveAdvisoriesSection0 />
        <PrescriptiveAdvisoriesSection1 />
        <PrescriptiveAdvisoriesSection2 />
      </div>
    </div>
  );
}
