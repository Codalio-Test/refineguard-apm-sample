import { NavLink, useParams } from "react-router-dom";
import { Activity, HeartPulse, Waves } from "lucide-react";

export default function AssetContextNavigation() {
  const { assetId = "P-204A" } = useParams();
  const items = [{ path: "health-summary", label: "Health summary", icon: HeartPulse }, { path: "diagnostics", label: "Diagnostics", icon: Activity }, { path: "spectral-analytics", label: "Spectral analytics", icon: Waves }];
  return (
    <nav className="flex flex-wrap items-center gap-1 border-b border-border" aria-label="Asset views">
    {items.map((item) => <NavLink key={item.path} to={`/assets/${assetId}/${item.path}`} className={({ isActive }) => `flex items-center gap-2 whitespace-nowrap border-b-2 px-3 py-2 text-sm font-medium transition-colors ${isActive ? "border-primary text-primary" : "border-transparent text-muted-foreground hover:text-foreground"}`}><item.icon className="h-4 w-4" />{item.label}</NavLink>)}
    </nav>
  );
}

export { AssetContextNavigation };
