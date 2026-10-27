import type { ReactNode } from "react";
import { Download } from "lucide-react";
import { Button } from "./ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card";

export default function OperationalChartFrame({ title, subtitle, children }: { title: string; subtitle?: string; children: ReactNode }) {
  return (
    <Card className="overflow-hidden shadow-sm">
    <CardHeader className="flex flex-row items-center justify-between gap-4 border-b border-border py-4">
    <div><CardTitle className="text-base">{title}</CardTitle>{subtitle && <p className="mt-1 text-xs text-muted-foreground">{subtitle}</p>}</div>
    <Button variant="outline" size="sm" onClick={() => window.alert(`Exported ${title}`)}><Download className="h-4 w-4" />Export</Button>
    </CardHeader>
    <CardContent className="p-4">{children}</CardContent>
    </Card>
  );
}

export { OperationalChartFrame };
