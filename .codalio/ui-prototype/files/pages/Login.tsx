import { LockKeyhole, ShieldCheck } from "lucide-react";
import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Alert, AlertDescription } from "../components/ui/alert";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "../components/ui/card";
import { Input } from "../components/ui/input";
import { Label } from "../components/ui/label";

function LoginSection0() {
  const navigate=useNavigate();
  const [user,setUser]=useState("");
  const [loading,setLoading]=useState(false);
  return (
    <section className="grid min-h-screen place-items-center bg-background p-4"><Card className="w-full max-w-md border-border shadow-md"><CardHeader className="text-center"><div className="mx-auto mb-3 flex h-12 w-12 items-center justify-center rounded-lg bg-primary text-primary-foreground"><ShieldCheck className="h-6 w-6"/></div><CardTitle className="text-2xl">RefineGuard APM</CardTitle><CardDescription>Sign in to BRR-OT.LOCAL</CardDescription></CardHeader><CardContent><form id="login" className="space-y-4" onSubmit={(e)=>{e.preventDefault();setLoading(true);window.setTimeout(()=>navigate("/fleet-overview"),500)}}><div className="space-y-2"><Label htmlFor="user">Domain username</Label><Input id="user" value={user} onChange={(e)=>setUser(e.target.value)} placeholder="operator.name" required/></div><div className="space-y-2"><Label htmlFor="pass">Password</Label><Input id="pass" type="password" required/></div><Alert><LockKeyhole className="h-4 w-4"/><AlertDescription>Authentication remains inside the sealed OT network.</AlertDescription></Alert></form></CardContent><CardFooter><Button form="login" className="w-full" disabled={loading}>{loading?"Authenticating…":"Secure sign in"}</Button></CardFooter></Card></section>
  );
}

export default function Login() {
  return (
    <div className="w-full min-w-0 overflow-x-hidden">
      <div className="flex flex-col gap-4 w-full min-w-0">
        <LoginSection0 />
      </div>
    </div>
  );
}
