import { SeverityBadge } from "../components/SeverityBadge";
import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../components/ui/table";

function UnitRiskMatrixSection0() {
  const [range,setRange]=useState("Current shift");
  return (
    <section className="flex flex-wrap items-center gap-2"><div className="mr-auto"><h1 className="text-2xl font-semibold">Operations Unit Risk Matrix</h1><p className="text-sm text-muted-foreground">{range} · Production risk projection</p></div>{["Current shift","24 hours","7 days","30 days"].map((h)=><Button key={h} variant={range===h?"default":"outline"} onClick={()=>setRange(h)}>{h}</Button>)}</section>
  );
}

function UnitRiskMatrixSection1() {
  return (
    <section className="grid gap-3 xl:grid-cols-[1fr_360px]"><Card><CardHeader><CardTitle className="text-base">Production risk matrix</CardTitle></CardHeader><CardContent className="overflow-x-auto"><Table><TableHeader><TableRow>{["Unit","Rate","Critical train","Trip probability","Derate","Exposure"].map((h)=><TableHead key={h}>{h}</TableHead>)}</TableRow></TableHeader><TableBody>{[["CDU-1","92%","P-204A","18%","12 kbpd","$418k/day"],["FCC-2","88%","C-101B","9%","8 kbpd","$302k/day"],["HCU-3","96%","P-108C","3%","—","$74k/day"]].map((r)=><TableRow key={r[0]}>{r.map((c)=><TableCell key={c} className="font-mono text-xs">{c}</TableCell>)}</TableRow>)}</TableBody></Table></CardContent></Card><Card><CardHeader><CardTitle className="text-base">Cross-unit risk map</CardTitle></CardHeader><CardContent className="grid grid-cols-4 gap-2">{Array.from({length:16},(_,i)=><div key={i} className={`aspect-square rounded-md ${i<2?"bg-red-500":i<6?"bg-amber-400":"bg-emerald-500"}`} title={`Asset ${i+1}`}/>)}</CardContent></Card></section>
  );
}

function UnitRiskMatrixSection2() {
  const navigate=useNavigate();
  return (
    <section className="grid gap-3 lg:grid-cols-2"><Card><CardHeader><CardTitle className="text-base">Derate recommendation</CardTitle></CardHeader><CardContent><p className="text-sm leading-6 text-muted-foreground">Reduce CDU-1 charge rate by 8% until P-204A bearing inspection. Expected trip risk falls from 18% to 6%.</p><Button className="mt-4" onClick={()=>navigate("/prescriptive-advisories")}>Open advisory</Button></CardContent></Card><Card><CardHeader><CardTitle className="text-base">Unit risk trend</CardTitle></CardHeader><CardContent><div className="h-28"><svg viewBox="0 0 500 100" className="h-full w-full text-primary"><polyline points="0,80 70,74 140,76 210,58 280,62 350,36 420,40 500,18" fill="none" stroke="currentColor" strokeWidth="3"/></svg></div></CardContent></Card></section>
  );
}

export default function UnitRiskMatrix() {
  return (
    <div className="w-full min-w-0 overflow-x-hidden">
      <div className="flex flex-col gap-4 w-full min-w-0">
        <UnitRiskMatrixSection0 />
        <UnitRiskMatrixSection1 />
        <UnitRiskMatrixSection2 />
      </div>
    </div>
  );
}
