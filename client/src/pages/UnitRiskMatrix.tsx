import React from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { useUnitRiskMatrix } from "../hooks/useApiQueries";

// The design's horizon buttons mapped onto the aggregate's range keys.
const RANGE_KEYS: Record<string, string> = { "Current shift": "current_shift", "24 hours": "24h", "7 days": "7d", "30 days": "30d" };
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../components/ui/table";

function UnitRiskMatrixSection0() {
  const [searchParams,setSearchParams]=useSearchParams();
  const range=searchParams.get("range")??"Current shift";
  const setRange=(value:string)=>{const params=new URLSearchParams(searchParams); params.set("range",value); setSearchParams(params,{replace:true});};
  return (
    <section className="flex flex-wrap items-center gap-2"><div className="mr-auto"><h1 className="text-2xl font-semibold">Operations Unit Risk Matrix</h1><p className="text-sm text-muted-foreground">{range} · Production risk projection</p></div>{["Current shift","24 hours","7 days","30 days"].map((h)=><Button key={h} variant={range===h?"default":"outline"} onClick={()=>setRange(h)}>{h}</Button>)}</section>
  );
}

function UnitRiskMatrixSection1() {
  const [searchParams]=useSearchParams();
  const range=searchParams.get("range")??"Current shift";
  const { data: matrix } = useUnitRiskMatrix(RANGE_KEYS[range] ?? "current_shift");
  const rows = (matrix?.rows ?? []) as Array<Record<string, unknown>>;
  const riskCells = matrix?.risk_cells ?? [];
  return (
    <section className="grid gap-3 xl:grid-cols-[1fr_360px]"><Card><CardHeader><CardTitle className="text-base">Production risk matrix</CardTitle></CardHeader><CardContent className="overflow-x-auto"><Table><TableHeader><TableRow>{["Unit","Rate","Critical train","Trip probability","Derate","Exposure"].map((h)=><TableHead key={h}>{h}</TableHead>)}</TableRow></TableHeader><TableBody>{rows.map((r)=><TableRow key={String(r.unit)}>{[r.unit,r.rate,r.critical_train,r.trip_probability,r.derate,r.exposure].map((c)=><TableCell key={String(c)} className="font-mono text-xs">{String(c ?? "—")}</TableCell>)}</TableRow>)}</TableBody></Table></CardContent></Card><Card><CardHeader><CardTitle className="text-base">Cross-unit risk map</CardTitle></CardHeader><CardContent className="grid grid-cols-4 gap-2">{Array.from({length:Math.max(riskCells.length,1)},(_,i)=><div key={i} className={`aspect-square rounded-md ${i<2?"bg-red-500":i<6?"bg-amber-400":"bg-emerald-500"}`} title={String(riskCells[i]?.horizon ?? `Cell ${i+1}`)}/>)}</CardContent></Card></section>
  );
}

function UnitRiskMatrixSection2() {
  const navigate=useNavigate();
  const [searchParams]=useSearchParams();
  const range=searchParams.get("range")??"Current shift";
  const { data: matrix } = useUnitRiskMatrix(RANGE_KEYS[range] ?? "current_shift");
  const rows = (matrix?.rows ?? []) as Array<Record<string, unknown>>;
  const trendPoints = rows.map((row,i)=>{
    const x = rows.length <= 1 ? 250 : (i / (rows.length - 1)) * 500;
    const value = Number(String(row.trip_probability ?? "0").replace("%", ""));
    return `${x.toFixed(1)},${(100 - Math.min(Math.max(value,0),100) * 0.8).toFixed(1)}`;
  }).join(" ");
  return (
    <section className="grid gap-3 lg:grid-cols-2"><Card><CardHeader><CardTitle className="text-base">Derate recommendation</CardTitle></CardHeader><CardContent><p className="text-sm leading-6 text-muted-foreground">{matrix?.derate_recommendation ?? "No derating advisory is currently recommended."}</p><Button className="mt-4" onClick={()=>navigate("/prescriptive-advisories")}>Open advisory</Button></CardContent></Card><Card><CardHeader><CardTitle className="text-base">Unit risk trend</CardTitle></CardHeader><CardContent><div className="h-28"><svg viewBox="0 0 500 100" className="h-full w-full text-primary"><polyline points={trendPoints} fill="none" stroke="currentColor" strokeWidth="3"/></svg></div></CardContent></Card></section>
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
