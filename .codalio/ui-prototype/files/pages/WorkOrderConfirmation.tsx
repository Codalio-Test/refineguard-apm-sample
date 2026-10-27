import { ShieldCheck } from "lucide-react";
import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Alert, AlertDescription, AlertTitle } from "../components/ui/alert";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Input } from "../components/ui/input";
import { Label } from "../components/ui/label";
import { Textarea } from "../components/ui/textarea";

function WorkOrderConfirmationSection0() {
  const [finding,setFinding]=useState("Replace outboard bearing; BPFO signature confirmed.");
  return (
    <section className="grid gap-3 xl:grid-cols-[1fr_360px]"><Card><CardHeader><CardTitle>Work Order Confirmation</CardTitle></CardHeader><CardContent className="grid gap-4 md:grid-cols-2"><div><Label>Asset</Label><Input value="P-204A" readOnly/></div><div><Label>Target system</Label><Input value="SAP PM" readOnly/></div><div className="md:col-span-2"><Label>Diagnostic finding</Label><Textarea value={finding} onChange={(e)=>setFinding(e.target.value)}/></div><div><Label>Priority</Label><Input defaultValue="P2 · Urgent"/></div><div><Label>Required by</Label><Input type="date" defaultValue="2025-05-16"/></div></CardContent></Card><Card><CardHeader><CardTitle className="text-base">CMMS payload</CardTitle></CardHeader><CardContent><pre className="overflow-auto whitespace-pre-wrap rounded-md bg-slate-950 p-4 text-xs text-cyan-200">{`SYSTEM: SAP_PM\nEQUIPMENT: P-204A\nTYPE: PM02\nPRIORITY: 2\nSTATUS: VALID`}</pre></CardContent></Card></section>
  );
}

function WorkOrderConfirmationSection1() {
  const navigate=useNavigate();
  const [sent,setSent]=useState(false);
  return (
    <section className="sticky bottom-0"><Alert className="bg-card shadow-md"><ShieldCheck className="h-4 w-4"/><AlertTitle>{sent?"Work order dispatched":"Ready for local dispatch"}</AlertTitle><AlertDescription className="flex flex-wrap items-center justify-between gap-3"><span>{sent?"SAP PM reference 450018204 created.":"Dispatch writes to the local CMMS connector only."}</span><div className="flex gap-2"><Button variant="outline" onClick={()=>navigate("/prescriptive-advisories")}>Back</Button><Button onClick={()=>setSent(true)} disabled={sent}>{sent?"Dispatched":"Confirm and dispatch"}</Button></div></AlertDescription></Alert></section>
  );
}

export default function WorkOrderConfirmation() {
  return (
    <div className="w-full min-w-0 overflow-x-hidden">
      <div className="flex flex-col gap-4 w-full min-w-0">
        <WorkOrderConfirmationSection0 />
        <WorkOrderConfirmationSection1 />
      </div>
    </div>
  );
}
