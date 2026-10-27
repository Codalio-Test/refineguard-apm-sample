import { CircleCheck } from "lucide-react";
import React, { useState } from "react";
import { Alert, AlertDescription, AlertTitle } from "../components/ui/alert";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Input } from "../components/ui/input";
import { Label } from "../components/ui/label";

function AssetHierarchyBuilderSection0() {
  const [status,setStatus]=useState("ISA-95 / ISO 14224");
  return (
    <section className="flex flex-wrap items-center gap-2"><div className="mr-auto"><h1 className="text-2xl font-semibold">Asset Hierarchy Builder</h1><p className="text-sm text-muted-foreground">{status}</p></div>{["unit","train","asset"].map((item)=><Button key={item} variant="outline" onClick={()=>setStatus(`New ${item} added to draft`)}>Add {item}</Button>)}<Button onClick={()=>setStatus("Hierarchy validated and published")}>Validate & publish</Button></section>
  );
}

function AssetHierarchyBuilderSection1() {
  const [node,setNode]=useState("P-204A");
  const [saved,setSaved]=useState(false);
  return (
    <section className="grid gap-3 xl:grid-cols-[360px_1fr]"><Card><CardHeader><CardTitle className="text-base">Equipment tree</CardTitle></CardHeader><CardContent className="space-y-1">{["BRR Complex","└ CDU-1","  └ Charge Train A","    └ P-204A","      └ Outboard Bearing"].map((n)=><button key={n} onClick={()=>setNode(n.trim())} className="block w-full rounded p-2 text-left font-mono text-xs hover:bg-muted">{n}</button>)}</CardContent></Card><Card><CardHeader><CardTitle className="text-base">{node}</CardTitle></CardHeader><CardContent className="grid gap-3 md:grid-cols-2"><div><Label>Equipment tag</Label><Input defaultValue="P-204A"/></div><div><Label>Class</Label><Input defaultValue="Centrifugal pump"/></div><div><Label>Manufacturer</Label><Input defaultValue="Sulzer"/></div><div><Label>Criticality</Label><Input defaultValue="Production critical"/></div><Button onClick={()=>setSaved(true)}>{saved?"Metadata saved":"Save metadata"}</Button></CardContent></Card></section>
  );
}

function AssetHierarchyBuilderSection2() {
  return (
    <section><Alert><CircleCheck className="h-4 w-4"/><AlertTitle>Hierarchy validation passed</AlertTitle><AlertDescription>Unique tags, parent integrity, required metadata, and historian bindings are valid. Two optional seal-plan fields remain empty.</AlertDescription></Alert></section>
  );
}

export default function AssetHierarchyBuilder() {
  return (
    <div className="w-full min-w-0 overflow-x-hidden">
      <div className="flex flex-col gap-4 w-full min-w-0">
        <AssetHierarchyBuilderSection0 />
        <AssetHierarchyBuilderSection1 />
        <AssetHierarchyBuilderSection2 />
      </div>
    </div>
  );
}
