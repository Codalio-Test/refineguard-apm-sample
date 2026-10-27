import { ShieldCheck } from "lucide-react";
import React, { useState } from "react";
import { useLocation, useNavigate, useSearchParams } from "react-router-dom";
import { useDispatchWorkOrder, useWorkOrderContext } from "../hooks/useApiQueries";
import { firstError, workOrderDispatchSchema } from "../lib/validation";
import { apiErrorMessage } from "../lib/apiError";
import { Alert, AlertDescription, AlertTitle } from "../components/ui/alert";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Input } from "../components/ui/input";
import { Label } from "../components/ui/label";
import { Textarea } from "../components/ui/textarea";

function WorkOrderConfirmationSection0() {
  const [searchParams,setSearchParams]=useSearchParams();
  // The advisory carried from the queue selects which work package is being
  // confirmed; the editable priority and required-by dates live in the URL so the
  // dispatch panel below sends exactly what was typed.
  const location=useLocation();
  const routedId=(location.state as { advisoryId?: number } | null)?.advisoryId;
  const { order, advisory }=useWorkOrderContext(routedId);
  const priority = searchParams.get("priority") ?? String(order?.priority ?? "");
  const requiredBy = searchParams.get("required_by") ?? (order?.required_by ? String(order.required_by).slice(0,10) : "");
  const update=(key:string,value:string)=>{const params=new URLSearchParams(searchParams); if(value) params.set(key,value); else params.delete(key); setSearchParams(params,{replace:true});};
  const [draftFinding,setDraftFinding]=useState("");
  const finding = draftFinding || advisory?.recommendation || advisory?.recommended_action || "";
  const payloadPreview = [
    `SYSTEM: ${String(order?.cmms_type ?? "SAP PM").replace(/\s+/g, "_").toUpperCase()}`,
    `EQUIPMENT: ${order?.asset_tag ?? advisory?.asset_tag ?? "—"}`,
    `ADVISORY: ${advisory?.advisory_code ?? advisory?.id ?? "—"}`,
    `PRIORITY: ${priority || "—"}`,
    `STATUS: ${order?.sync_status ?? "AWAITING DISPATCH"}`,
  ].join("\n");
  return (
    <section className="grid gap-3 xl:grid-cols-[1fr_360px]"><Card><CardHeader><CardTitle>Work Order Confirmation</CardTitle></CardHeader><CardContent className="grid gap-4 md:grid-cols-2"><div><Label>Asset</Label><Input value={order?.asset_tag ?? advisory?.asset_tag ?? "—"} readOnly/></div><div><Label>Target system</Label><Input value={order?.cmms_type ?? "SAP PM"} readOnly/></div><div className="md:col-span-2"><Label>Diagnostic finding</Label><Textarea value={finding} onChange={(e)=>setDraftFinding(e.target.value)}/></div><div><Label>Priority</Label><Input value={priority} onChange={(e)=>update("priority",e.target.value)} placeholder="P2 · Urgent"/></div><div><Label>Required by</Label><Input type="date" value={requiredBy} onChange={(e)=>update("required_by",e.target.value)}/></div></CardContent></Card><Card><CardHeader><CardTitle className="text-base">CMMS payload</CardTitle></CardHeader><CardContent><pre className="overflow-auto whitespace-pre-wrap rounded-md bg-slate-950 p-4 text-xs text-cyan-200">{payloadPreview}</pre></CardContent></Card></section>
  );
}

function WorkOrderConfirmationSection1() {
  const navigate=useNavigate();
  const location=useLocation();
  const [searchParams]=useSearchParams();
  const dispatch=useDispatchWorkOrder();
  const routedId=(location.state as { advisoryId?: number } | null)?.advisoryId;
  const { order, advisory }=useWorkOrderContext(routedId);
  const [validationError,setValidationError]=useState("");
  const cmmsType = order?.cmms_type ?? "SAP PM";
  const sent = dispatch.isSuccess || order?.sync_status === "Dispatched";
  // The server nests the created order under `work_order` and reports failures
  // through the shared error envelope, so read the reference from there and
  // surface messages with the shared helper.
  const result = dispatch.data;
  const reference = result?.work_order?.external_order_number ?? order?.external_order_number ?? null;
  const simulated = result?.simulated ?? false;
  const errorMessage = validationError || (dispatch.isError ? apiErrorMessage(dispatch.error, "The dispatch could not be completed.") : null);
  const dispatchWorkOrder=()=>{
    if(!advisory?.id) return;
    const parsed = workOrderDispatchSchema.safeParse({
      priority: searchParams.get("priority") ?? String(order?.priority ?? ""),
      required_by: searchParams.get("required_by") ?? (order?.required_by ? String(order.required_by).slice(0,10) : ""),
    });
    if(!parsed.success){ setValidationError(firstError(parsed.error)); return; }
    setValidationError("");
    dispatch.mutate({ id: advisory.id, cmms_type: cmmsType, priority: parsed.data.priority, required_by: parsed.data.required_by || undefined });
  };
  const title = sent ? (simulated ? "Work order handed to the SIMULATED CMMS" : "Work order dispatched") : "Ready for local dispatch";
  const summary = sent
    ? (simulated
        ? `SIMULATED — no CMMS endpoint is configured; ${cmmsType} reference ${reference ?? "—"} is not confirmed.`
        : `${cmmsType} reference ${reference ?? "—"} created.`)
    : (errorMessage ?? "Dispatch writes to the local CMMS connector only.");
  return (
    <section className="sticky bottom-0"><Alert className="bg-card shadow-md"><ShieldCheck className="h-4 w-4"/><AlertTitle>{title}</AlertTitle><AlertDescription className="flex flex-wrap items-center justify-between gap-3"><span>{summary}</span><div className="flex gap-2"><Button variant="outline" onClick={()=>navigate("/prescriptive-advisories")}>Back</Button><Button onClick={dispatchWorkOrder} disabled={sent || !advisory?.id || dispatch.isPending}>{sent?"Dispatched":dispatch.isPending?"Dispatching…":"Confirm and dispatch"}</Button></div></AlertDescription></Alert></section>
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
