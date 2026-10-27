import { SeverityBadge } from "../components/SeverityBadge";
import React, { useState } from "react";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Textarea } from "../components/ui/textarea";

function OperationsShiftLogSection0() {
  const [status,setStatus]=useState("");
  return (
    <section className="flex flex-wrap items-center gap-2"><div className="mr-auto"><h1 className="text-2xl font-semibold">Operations Shift Log</h1><p className="text-sm text-muted-foreground">{status||"Day Shift A · 06:00–18:00"}</p></div><Button variant="outline" onClick={()=>setStatus("Handover exported locally")}>Export handover</Button><Button onClick={()=>setStatus("New entry ready below")}>Start new entry</Button></section>
  );
}

function OperationsShiftLogSection1() {
  const [notes,setNotes]=useState("CDU-1 operating at 84% rate. P-204A advisory open; bearing replacement planned. Monitor temperature hourly.");
  const [saved,setSaved]=useState(false);
  return (
    <section className="grid gap-3 xl:grid-cols-[1fr_420px]"><Card><CardHeader><CardTitle className="text-base">Shift event timeline</CardTitle></CardHeader><CardContent className="space-y-4">{[["10:42","P-204A bearing alarm acknowledged","critical"],["09:18","CDU-1 charge rate reduced 8%","warning"],["07:04","PI historian backfill completed","healthy"]].map((e)=><div key={e[0]} className="flex gap-4 border-l-2 border-primary pl-4"><span className="font-mono text-xs text-muted-foreground">{e[0]}</span><p className="flex-1 text-sm">{e[1]}</p><SeverityBadge severity={e[2]}/></div>)}</CardContent></Card><Card><CardHeader><CardTitle className="text-base">Shift handover</CardTitle></CardHeader><CardContent className="space-y-3"><Textarea rows={8} value={notes} onChange={(e)=>setNotes(e.target.value)}/><Button onClick={()=>setSaved(true)}>{saved?"Handover saved":"Save handover"}</Button></CardContent></Card></section>
  );
}

export default function OperationsShiftLog() {
  return (
    <div className="w-full min-w-0 overflow-x-hidden">
      <div className="flex flex-col gap-4 w-full min-w-0">
        <OperationsShiftLogSection0 />
        <OperationsShiftLogSection1 />
      </div>
    </div>
  );
}
