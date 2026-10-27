import { SeverityBadge } from "../components/SeverityBadge";
import React, { useState } from "react";
import { useModelIndex, useModelStore, useModelUpdate } from "@rhino-dev/rhino-react";
import { useAppOwner } from "../contexts/appOwner";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Textarea } from "../components/ui/textarea";

function OperationsShiftLogSection0() {
  const [status,setStatus]=useState("");
  const { data: entriesResponse } = useModelIndex("shift_log_entries", { sort: "-occurred_at", perPage: 50 });
  const entries = entriesResponse?.data ?? [];
  // The handover bundle is written to the workstation, never to a network share.
  const exportHandover=()=>{
    const blob=new Blob([JSON.stringify(entries,null,2)],{type:"application/json"});
    const url=URL.createObjectURL(blob);
    const anchor=document.createElement("a");
    anchor.href=url;
    anchor.download="shift-handover.json";
    anchor.click();
    URL.revokeObjectURL(url);
    setStatus("Handover exported locally");
  };
  return (
    <section className="flex flex-wrap items-center gap-2"><div className="mr-auto"><h1 className="text-2xl font-semibold">Operations Shift Log</h1><p className="text-sm text-muted-foreground">{status||"Day Shift A · 06:00–18:00"}</p></div><Button variant="outline" onClick={exportHandover}>Export handover</Button><Button onClick={()=>setStatus("New entry ready below")}>Start new entry</Button></section>
  );
}

function OperationsShiftLogSection1() {
  const { user } = useAppOwner();
  const { data: entriesResponse } = useModelIndex("shift_log_entries", { sort: "-occurred_at", perPage: 50 });
  const entries = entriesResponse?.data ?? [];
  const timeline = entries.map((entry) => ({
    id: entry.id,
    time: entry.occurred_at ? new Date(entry.occurred_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }) : "—",
    message: entry.message ?? "Event recorded",
    severity: entry.severity ?? "info",
  }));
  const latest = entries[0] ?? null;
  const [draft,setDraft]=useState("");
  const [saved,setSaved]=useState(false);
  const notes = draft || latest?.unit_status || "";
  const store = useModelStore("shift_log_entries");
  const updateEntry = useModelUpdate("shift_log_entries");
  const onSaved = () => setSaved(true);
  const saveHandover=()=>{
    setSaved(false);
    if (latest?.id) {
      updateEntry.mutate({ id: latest.id, data: { message: notes, unit_status: notes } }, { onSuccess: onSaved });
      return;
    }
    store.mutate(
      { message: notes, unit_status: notes, occurred_at: new Date().toISOString(), shift_label: "Day Shift A", event_type: "HANDOVER", severity: "info", author_id: (user as { id?: number } | null)?.id ?? undefined },
      { onSuccess: onSaved },
    );
  };
  return (
    <section className="grid gap-3 xl:grid-cols-[1fr_420px]"><Card><CardHeader><CardTitle className="text-base">Shift event timeline</CardTitle></CardHeader><CardContent className="space-y-4">{timeline.map((e)=><div key={e.id} className="flex gap-4 border-l-2 border-primary pl-4"><span className="font-mono text-xs text-muted-foreground">{e.time}</span><p className="flex-1 text-sm">{e.message}</p><SeverityBadge severity={e.severity}/></div>)}</CardContent></Card><Card><CardHeader><CardTitle className="text-base">Shift handover</CardTitle></CardHeader><CardContent className="space-y-3"><Textarea rows={8} value={notes} onChange={(e)=>{setDraft(e.target.value); setSaved(false);}}/><Button onClick={saveHandover} disabled={store.isPending || updateEntry.isPending}>{saved?"Handover saved":"Save handover"}</Button></CardContent></Card></section>
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
