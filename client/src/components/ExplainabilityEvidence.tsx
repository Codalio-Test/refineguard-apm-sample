import { Fingerprint } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card";
import { Progress } from "./ui/progress";

export default function ExplainabilityEvidence({ evidence = [] }: { evidence?: Array<{ label: string; value: number }> }) {
  return (
    <Card className="shadow-sm">
    <CardHeader className="pb-3"><CardTitle className="flex items-center gap-2 text-base"><Fingerprint className="h-4 w-4 text-primary" />Explainability evidence</CardTitle></CardHeader>
    <CardContent className="space-y-4">
    {evidence.map((item) => <div key={item.label} className="space-y-1.5"><div className="flex justify-between gap-3 text-sm"><span className="text-foreground">{item.label}</span><span className="font-mono text-muted-foreground">{item.value}%</span></div><Progress value={item.value} /></div>)}
    </CardContent>
    </Card>
  );
}

export { ExplainabilityEvidence };
