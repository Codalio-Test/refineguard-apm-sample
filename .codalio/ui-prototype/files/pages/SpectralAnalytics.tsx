import { AssetContextNavigation } from "../components/AssetContextNavigation";
import { OperationalChartFrame } from "../components/OperationalChartFrame";
import React, { useState } from "react";
import { useParams } from "react-router-dom";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../components/ui/select";
import { Slider } from "../components/ui/slider";

function SpectralAnalyticsSection0() {
  const [channel,setChannel]=useState("OB Horizontal");
  const [harmonics,setHarmonics]=useState(false);
  const [markers,setMarkers]=useState(true);
  return (
    <section className="space-y-4"><AssetContextNavigation/><div className="flex flex-wrap items-center gap-2"><h1 className="mr-auto text-2xl font-semibold">Spectral Workbench</h1><Select value={channel} onValueChange={setChannel}><SelectTrigger className="w-44"><SelectValue/></SelectTrigger><SelectContent>{["OB Horizontal","OB Vertical","OB Axial"].map((c)=><SelectItem key={c} value={c}>{c}</SelectItem>)}</SelectContent></Select><Button variant={harmonics?"default":"outline"} onClick={()=>setHarmonics(!harmonics)}>Harmonics {harmonics?"on":"off"}</Button><Button variant={markers?"default":"outline"} onClick={()=>setMarkers(!markers)}>Bearing markers {markers?"on":"off"}</Button></div></section>
  );
}

function SpectralAnalyticsSection1() {
  return (
    <section className="grid gap-3 xl:grid-cols-[1fr_280px]"><OperationalChartFrame title="FFT spectrum" subtitle="Velocity mm/s RMS · Frequency Hz"><div className="h-80 bg-[linear-gradient(to_right,var(--border)_1px,transparent_1px),linear-gradient(to_bottom,var(--border)_1px,transparent_1px)] bg-[size:48px_36px]"><svg viewBox="0 0 800 280" className="h-full w-full text-primary"><polyline points="0,260 80,252 130,245 160,35 180,242 300,220 320,110 345,230 470,205 500,70 520,225 650,180 690,145 720,230 800,210" fill="none" stroke="currentColor" strokeWidth="2"/></svg></div></OperationalChartFrame><Card><CardHeader><CardTitle className="text-base">Spectral readout</CardTitle></CardHeader><CardContent className="space-y-4">{[["Running speed","29.8 Hz"],["Cursor","59.6 Hz"],["Amplitude","4.82 mm/s"],["Order","2.00X"],["Δ baseline","+3.14"]].map((r)=><div key={r[0]} className="flex justify-between text-sm"><span className="text-muted-foreground">{r[0]}</span><span className="font-mono">{r[1]}</span></div>)}</CardContent></Card></section>
  );
}

function SpectralAnalyticsSection2() {
  const [slice,setSlice]=useState([18]);
  return (
    <section className="grid gap-3 lg:grid-cols-2"><Card><CardHeader><CardTitle className="text-base">Waterfall timeline</CardTitle></CardHeader><CardContent><div className="mb-4 h-40 bg-gradient-to-br from-cyan-950 via-sky-700 to-amber-400 opacity-90"/><Slider value={slice} onValueChange={setSlice} max={24}/><p className="mt-2 font-mono text-xs text-muted-foreground">Slice {slice[0]} / 24</p></CardContent></Card><Card><CardHeader><CardTitle className="text-base">Orbit plot</CardTitle></CardHeader><CardContent><svg viewBox="0 0 300 180" className="h-48 w-full text-primary"><ellipse cx="150" cy="90" rx="92" ry="45" fill="none" stroke="currentColor" strokeWidth="2" transform="rotate(-18 150 90)"/><ellipse cx="150" cy="90" rx="65" ry="30" fill="none" stroke="currentColor" opacity=".4"/></svg></CardContent></Card></section>
  );
}

export default function SpectralAnalytics() {
  return (
    <div className="w-full min-w-0 overflow-x-hidden">
      <div className="flex flex-col gap-4 w-full min-w-0">
        <SpectralAnalyticsSection0 />
        <SpectralAnalyticsSection1 />
        <SpectralAnalyticsSection2 />
      </div>
    </div>
  );
}
