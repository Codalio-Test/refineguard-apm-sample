import { AssetContextNavigation } from "../components/AssetContextNavigation";
import { OperationalChartFrame } from "../components/OperationalChartFrame";
import React, { useState } from "react";
import { useParams, useSearchParams } from "react-router-dom";
import { useSpectrumContext } from "../hooks/useApiQueries";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../components/ui/select";
import { Slider } from "../components/ui/slider";

function SpectralAnalyticsSection0() {
  const [searchParams,setSearchParams]=useSearchParams();
  const channel=searchParams.get("channel")??"OB Horizontal";
  const setChannel=(next:string)=>{const params=new URLSearchParams(searchParams); params.set("channel",next); setSearchParams(params,{replace:true});};
  const [harmonics,setHarmonics]=useState(false);
  const [markers,setMarkers]=useState(true);
  return (
    <section className="space-y-4"><AssetContextNavigation/><div className="flex flex-wrap items-center gap-2"><h1 className="mr-auto text-2xl font-semibold">Spectral Workbench</h1><Select value={channel} onValueChange={setChannel}><SelectTrigger className="w-44"><SelectValue/></SelectTrigger><SelectContent>{["OB Horizontal","OB Vertical","OB Axial"].map((c)=><SelectItem key={c} value={c}>{c}</SelectItem>)}</SelectContent></Select><Button variant={harmonics?"default":"outline"} onClick={()=>setHarmonics(!harmonics)}>Harmonics {harmonics?"on":"off"}</Button><Button variant={markers?"default":"outline"} onClick={()=>setMarkers(!markers)}>Bearing markers {markers?"on":"off"}</Button></div></section>
  );
}

function SpectralAnalyticsSection1() {
  const {assetId="P-204A"}=useParams();
  const [searchParams]=useSearchParams();
  const channel=searchParams.get("channel")??"OB Horizontal";
  const { snapshot }=useSpectrumContext(assetId, channel);
  const spectrum = snapshot?.spectrum ?? [];
  const maxHz = spectrum.reduce((peak, point) => Math.max(peak, point.hz ?? 0), 0) || 1;
  const maxAmplitude = spectrum.reduce((peak, point) => Math.max(peak, point.amplitude ?? 0), 0) || 1;
  const spectrumPoints = spectrum.map((point) => `${(((point.hz ?? 0) / maxHz) * 800).toFixed(1)},${(280 - ((point.amplitude ?? 0) / maxAmplitude) * 245).toFixed(1)}`).join(" ");
  const readout = [
    ["Running speed", snapshot?.running_speed_hz == null ? "—" : `${snapshot.running_speed_hz} Hz`],
    ["Cursor", snapshot?.cursor_hz == null ? "—" : `${snapshot.cursor_hz} Hz`],
    ["Amplitude", snapshot?.cursor_amplitude == null ? "—" : `${snapshot.cursor_amplitude} mm/s`],
    ["Order", snapshot?.cursor_order == null ? "—" : `${Number(snapshot.cursor_order).toFixed(2)}X`],
    ["Δ baseline", snapshot?.delta_baseline == null ? "—" : `${snapshot.delta_baseline > 0 ? "+" : ""}${snapshot.delta_baseline}`],
  ];
  return (
    <section className="grid gap-3 xl:grid-cols-[1fr_280px]"><OperationalChartFrame title="FFT spectrum" subtitle="Velocity mm/s RMS · Frequency Hz"><div className="h-80 bg-[linear-gradient(to_right,var(--border)_1px,transparent_1px),linear-gradient(to_bottom,var(--border)_1px,transparent_1px)] bg-[size:48px_36px]"><svg viewBox="0 0 800 280" className="h-full w-full text-primary"><polyline points={spectrumPoints} fill="none" stroke="currentColor" strokeWidth="2"/></svg></div></OperationalChartFrame><Card><CardHeader><CardTitle className="text-base">Spectral readout</CardTitle></CardHeader><CardContent className="space-y-4">{readout.map((r)=><div key={r[0]} className="flex justify-between text-sm"><span className="text-muted-foreground">{r[0]}</span><span className="font-mono">{r[1]}</span></div>)}</CardContent></Card></section>
  );
}

function SpectralAnalyticsSection2() {
  const {assetId="P-204A"}=useParams();
  const [searchParams]=useSearchParams();
  const channel=searchParams.get("channel")??"OB Horizontal";
  const { snapshot }=useSpectrumContext(assetId, channel);
  const waterfallTotal = snapshot?.waterfall?.length ?? 0;
  const [slice,setSlice]=useState([0]);
  const orbit = snapshot?.orbit ?? [];
  const orbitPoints = orbit.map((point) => `${(150 + (point.x_um ?? 0)).toFixed(1)},${(90 - (point.y_um ?? 0)).toFixed(1)}`).join(" ");
  return (
    <section className="grid gap-3 lg:grid-cols-2"><Card><CardHeader><CardTitle className="text-base">Waterfall timeline</CardTitle></CardHeader><CardContent><div className="mb-4 h-40 bg-gradient-to-br from-cyan-950 via-sky-700 to-amber-400 opacity-90"/><Slider value={slice} onValueChange={setSlice} max={Math.max(waterfallTotal - 1, 0)}/><p className="mt-2 font-mono text-xs text-muted-foreground">Slice {slice[0]} / {waterfallTotal}</p></CardContent></Card><Card><CardHeader><CardTitle className="text-base">Orbit plot</CardTitle></CardHeader><CardContent><svg viewBox="0 0 300 180" className="h-48 w-full text-primary"><polyline points={orbitPoints} fill="none" stroke="currentColor" strokeWidth="2"/></svg></CardContent></Card></section>
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
