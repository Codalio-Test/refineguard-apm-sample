import { Activity, ArrowRight, CheckCircle2, CircleCheck, Database, FileSearch, Network, RadioTower, ShieldCheck, Wrench } from "lucide-react";
import React from "react";
import { useNavigate } from "react-router-dom";
import { Badge } from "../components/ui/badge";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";

function LandingSection0() {
  const navigate = useNavigate();
  return (
    <section className="overflow-hidden rounded-xl border border-border bg-card">
      <div className="grid min-h-[480px] lg:grid-cols-[1fr_420px]">
        <div className="flex flex-col justify-center p-6 sm:p-10 lg:p-14">
          <Badge variant="outline" className="mb-6 w-fit gap-2 border-primary/40 bg-primary/5 text-primary"><RadioTower className="h-3.5 w-3.5" />Air-gapped predictive maintenance</Badge>
          <h1 className="max-w-3xl text-4xl font-semibold tracking-tight text-foreground lg:text-6xl">Deterministic machinery health for air-gapped refineries</h1>
          <p className="mt-6 max-w-2xl text-base leading-7 text-muted-foreground lg:text-lg">Triage rotating assets, explain failure fingerprints, and dispatch maintenance before production is at risk.</p>
          <div className="mt-8 flex flex-wrap gap-3"><Button size="lg" onClick={() => navigate("/fleet-overview")}>Open Fleet Overview<ArrowRight className="h-4 w-4" /></Button><Button size="lg" variant="outline" onClick={() => navigate("/login")}>Sign In</Button></div>
          <div className="mt-8 flex flex-wrap gap-x-6 gap-y-2 text-xs text-muted-foreground"><span className="flex items-center gap-1.5"><CheckCircle2 className="h-4 w-4 text-emerald-600" />No cloud dependency</span><span className="flex items-center gap-1.5"><CheckCircle2 className="h-4 w-4 text-emerald-600" />Explainable evidence</span></div>
        </div>
        <Card className="m-4 overflow-hidden border-border bg-slate-950 font-mono shadow-md lg:m-6"><div className="relative h-52"><img src="https://pixabay.com/get/g2d9ab341e064a8f53bfa6f119e98d059a01781e3242412dde9faf9319666f17cf31f810a0fcba337d730b8f5cee859851d6a57b9e5a86f61ce273b52ac8fd229_640.jpg" alt="Refinery operations at dusk" className="h-full w-full object-cover" /><div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/40 to-transparent" /><p className="absolute bottom-4 left-4 text-xs font-medium uppercase tracking-wider text-white">Local refinery node · online</p></div><CardContent className="space-y-4 p-5 text-xs text-slate-300"><div className="flex justify-between"><span>ASSET / P-204A</span><span className="text-red-300">CRITICAL</span></div><div className="h-24 rounded border border-slate-700 bg-slate-900 p-3"><svg viewBox="0 0 360 70" className="h-full w-full" aria-label="Vibration trend"><polyline points="0,52 35,49 70,50 105,43 140,47 175,30 210,37 245,18 280,29 315,10 360,15" fill="none" stroke="currentColor" strokeWidth="2" className="text-cyan-400" /></svg></div><div className="grid grid-cols-3 gap-3"><div><p className="text-slate-500">RMS</p><p className="mt-1 text-lg text-white">8.42</p></div><div><p className="text-slate-500">RISK</p><p className="mt-1 text-lg text-amber-300">92%</p></div><div><p className="text-slate-500">SYNC</p><p className="mt-1 text-lg text-emerald-300">OK</p></div></div></CardContent></Card>
      </div>
    </section>
  );
}

function LandingSection1() {
  const capabilities = [{ title: "Fleet triage", description: "Rank asset risk by process criticality and evidence strength.", icon: Activity }, { title: "Explainable diagnostics", description: "Trace every fault call to measured signatures and operating state.", icon: FileSearch }, { title: "Spectral workbench", description: "Inspect harmonics, sidebands, and bearing fault frequencies.", icon: Network }, { title: "CMMS dispatch", description: "Turn validated advisories into maintenance-ready work orders.", icon: Wrench }, { title: "Air-gapped governance", description: "Keep models, users, and audit evidence inside the facility.", icon: ShieldCheck }, { title: "Historian resiliency", description: "Monitor PI and PHD collection paths with local buffering.", icon: Database }];
  return (
    <section className="py-2">
      <div className="mb-5 flex items-end justify-between gap-4"><div><Badge variant="outline" className="mb-2">Capabilities</Badge><h2 className="text-2xl font-semibold text-foreground">Operational capabilities</h2></div><p className="hidden max-w-lg text-right text-sm text-muted-foreground md:block">Built for deterministic decisions inside restricted industrial networks.</p></div>
      <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">{capabilities.map((item) => <Card key={item.title} className="shadow-sm transition-colors hover:border-primary/50"><CardHeader className="pb-3"><div className="mb-3 flex h-9 w-9 items-center justify-center rounded-md bg-primary/10 text-primary"><item.icon className="h-5 w-5" /></div><CardTitle className="text-base">{item.title}</CardTitle></CardHeader><CardContent><p className="text-sm leading-6 text-muted-foreground">{item.description}</p></CardContent></Card>)}</div>
    </section>
  );
}

function LandingSection2() {
  const navigate = useNavigate();
  return (
    <section className="pb-4">
      <Card className="border-primary/40 bg-card shadow-sm"><CardContent className="flex flex-col gap-5 p-6 sm:flex-row sm:items-center sm:justify-between lg:p-8"><div><div className="mb-2 flex items-center gap-2 text-xs font-medium uppercase tracking-wide text-emerald-700 dark:text-emerald-300"><CircleCheck className="h-4 w-4" />Local telemetry is synchronized</div><h2 className="text-2xl font-semibold text-foreground">Enter the local operations workspace</h2><p className="mt-2 font-mono text-xs text-muted-foreground">PI 380ms · PHD Sync OK · Air-gap sealed</p></div><Button size="lg" onClick={() => navigate("/fleet-overview")}>Open RefineGuard<ArrowRight className="h-4 w-4" /></Button></CardContent></Card>
    </section>
  );
}

export default function Landing() {
  return (
    <div className="w-full min-w-0 overflow-x-hidden">
      <div className="mx-auto flex w-full max-w-7xl flex-col gap-6 px-4 py-6 sm:px-6 lg:gap-8 lg:px-8 lg:py-8 min-w-0">
        <LandingSection0 />
        <LandingSection1 />
        <LandingSection2 />
      </div>
    </div>
  );
}
