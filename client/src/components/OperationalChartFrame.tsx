import type { ReactNode } from "react";
import { useRef } from "react";
import { Download } from "lucide-react";
import { Button } from "./ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card";

export default function OperationalChartFrame({ title, subtitle, children }: { title: string; subtitle?: string; children: ReactNode }) {
  // The frame owns its own export: it serialises the chart it is framing to a
  // local SVG download. Nothing leaves the workstation, which is what an
  // air-gapped engineering bench requires.
  const contentRef = useRef<HTMLDivElement>(null);
  const exportChart = () => {
    const svg = contentRef.current?.querySelector("svg");
    if (!svg) return;
    const blob = new Blob([new XMLSerializer().serializeToString(svg)], { type: "image/svg+xml" });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `${title.toLowerCase().replace(/[^a-z0-9]+/g, "-")}.svg`;
    anchor.click();
    URL.revokeObjectURL(url);
  };
  return (
    <Card className="overflow-hidden shadow-sm">
    <CardHeader className="flex flex-row items-center justify-between gap-4 border-b border-border py-4">
    <div><CardTitle className="text-base">{title}</CardTitle>{subtitle && <p className="mt-1 text-xs text-muted-foreground">{subtitle}</p>}</div>
    <Button variant="outline" size="sm" onClick={exportChart}><Download className="h-4 w-4" />Export</Button>
    </CardHeader>
    <CardContent className="p-4" ref={contentRef}>{children}</CardContent>
    </Card>
  );
}

export { OperationalChartFrame };
