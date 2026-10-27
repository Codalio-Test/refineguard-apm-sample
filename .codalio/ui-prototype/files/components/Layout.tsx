import { useEffect, useState } from "react";
import { NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";
import { Activity, Boxes, BrainCircuit, Check, ChevronDown, ClipboardList, Database, Gauge, LayoutGrid, LogOut, Moon, ScrollText, ShieldCheck, Sparkles, Sun, UserRound } from "lucide-react";
import { GlobalAlertDrawer } from "./GlobalAlertDrawer";
import { Button } from "./ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "./ui/dialog";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger } from "./ui/dropdown-menu";
import { Input } from "./ui/input";
import { Label } from "./ui/label";
import { Sidebar, SidebarContent, SidebarFooter, SidebarGroup, SidebarGroupContent, SidebarGroupLabel, SidebarHeader, SidebarInset, SidebarMenu, SidebarMenuButton, SidebarMenuItem, SidebarProvider, SidebarTrigger } from "./ui/sidebar";

const navigation = [
  { label: "Operations", items: [
    { to: "/fleet-overview", label: "Fleet overview", icon: Gauge },
    { to: "/assets", label: "Asset registry", icon: Boxes },
    { to: "/prescriptive-advisories", label: "Advisories", icon: Sparkles },
    { to: "/operations/unit-risk-matrix", label: "Unit risk", icon: LayoutGrid },
    { to: "/operations/shift-log", label: "Shift log", icon: ClipboardList },
  ]},
  { label: "Model operations", items: [
    { to: "/model-management/retraining", label: "Retraining", icon: BrainCircuit },
    { to: "/model-management/evaluation", label: "Evaluation", icon: Activity },
  ]},
  { label: "System", items: [
    { to: "/admin/historian-connections", label: "Data connections", icon: Database },
    { to: "/admin/system-health", label: "System health", icon: ShieldCheck },
    { to: "/admin/security-audit", label: "Audit log", icon: ScrollText },
  ]},
];

const pageNames: Record<string, string> = {
  "/fleet-overview": "Fleet overview", "/assets": "Asset registry", "/prescriptive-advisories": "Prescriptive advisories",
  "/operations/unit-risk-matrix": "Unit risk matrix", "/operations/shift-log": "Operations shift log",
  "/model-management/retraining": "Model retraining", "/model-management/evaluation": "Model evaluation",
  "/admin/historian-connections": "Historian connections", "/admin/system-health": "System health", "/admin/security-audit": "Security audit",
};

export default function Layout() {
  const location = useLocation();
  const navigate = useNavigate();
  const isPublic = location.pathname === "/" || location.pathname === "/login";
  const [dark, setDark] = useState(false);
  const [profileOpen, setProfileOpen] = useState(false);
  const [profileSaved, setProfileSaved] = useState(false);
  const [displayName, setDisplayName] = useState("M. Chen");
  const [email, setEmail] = useState("m.chen@brr-ot.local");

  useEffect(() => {
    const saved = window.localStorage.getItem("refineguard-theme");
    const nextDark = saved ? saved === "dark" : window.matchMedia("(prefers-color-scheme: dark)").matches;
    setDark(nextDark);
    document.documentElement.classList.toggle("dark", nextDark);
  }, []);

  const toggleTheme = () => {
    const next = !dark;
    setDark(next);
    document.documentElement.classList.toggle("dark", next);
    window.localStorage.setItem("refineguard-theme", next ? "dark" : "light");
  };

  const pageTitle = pageNames[location.pathname] || (location.pathname.includes("/assets/") ? "Asset analysis" : "Operations");
  if (isPublic) return <Outlet />;

  return (
    <SidebarProvider>
      <Sidebar collapsible="icon" className="border-r border-sidebar-border/80 shadow-[8px_0_32px_rgba(2,6,23,0.12)]">
        <SidebarHeader className="h-20 justify-center border-b border-sidebar-border/70 px-3">
          <NavLink to="/fleet-overview" className="flex items-center gap-3 overflow-hidden rounded-xl px-1 py-1">
            <span className="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-sidebar-primary text-sidebar-primary-foreground shadow-[0_8px_24px_rgba(34,211,238,0.2)]"><ShieldCheck className="h-5 w-5" /><span className="absolute -right-0.5 -top-0.5 h-2.5 w-2.5 rounded-full border-2 border-sidebar bg-emerald-400" /></span>
            <span className="whitespace-nowrap"><span className="block text-sm font-bold tracking-[0.08em] text-sidebar-foreground">REFINEGUARD</span><span className="block text-xs text-sidebar-foreground/55">Asset performance</span></span>
          </NavLink>
        </SidebarHeader>
        <SidebarContent className="px-2.5 py-4">
          {navigation.map((group) => (
            <SidebarGroup key={group.label} className="py-2">
              <SidebarGroupLabel className="h-7 px-2.5 text-xs font-semibold uppercase tracking-[0.1em] text-sidebar-foreground/40">{group.label}</SidebarGroupLabel>
              <SidebarGroupContent><SidebarMenu className="gap-1">{group.items.map((item) => (
                <SidebarMenuItem key={item.to}><SidebarMenuButton asChild tooltip={item.label} className="h-10 rounded-lg">
                  <NavLink to={item.to} className={({ isActive }) => isActive ? "relative bg-sidebar-accent font-semibold text-sidebar-accent-foreground shadow-sm ring-1 ring-white/5 before:absolute before:-left-1 before:h-5 before:w-0.5 before:rounded-full before:bg-sidebar-primary" : "text-sidebar-foreground/65 hover:bg-sidebar-accent/60 hover:text-sidebar-foreground"}><item.icon className="h-4 w-4" /><span className="whitespace-nowrap">{item.label}</span></NavLink>
                </SidebarMenuButton></SidebarMenuItem>
              ))}</SidebarMenu></SidebarGroupContent>
            </SidebarGroup>
          ))}
        </SidebarContent>
        <SidebarFooter className="border-t border-sidebar-border/80 p-3">
          <div className="flex items-center gap-2.5 rounded-lg border border-sidebar-border bg-sidebar-accent/35 px-2.5 py-2 text-xs text-sidebar-foreground/70"><span className="relative flex h-2 w-2 shrink-0"><span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-40" /><span className="relative inline-flex h-2 w-2 rounded-full bg-emerald-400" /></span><span className="truncate">BRR node operational</span></div>
        </SidebarFooter>
      </Sidebar>
      <SidebarInset className="bg-transparent">
        <header className="sticky top-0 z-30 flex h-20 items-center justify-between border-b border-border/65 bg-card/80 px-4 shadow-[0_1px_0_rgba(15,23,42,0.025)] backdrop-blur-2xl sm:px-6 lg:px-8">
          <div className="flex min-w-0 items-center gap-3"><SidebarTrigger className="rounded-lg" /><div className="h-5 w-px bg-border" /><div className="min-w-0"><p className="truncate text-sm font-semibold tracking-tight text-foreground">{pageTitle}</p><p className="hidden text-xs text-muted-foreground sm:block">BRR-OT.LOCAL / Production environment</p></div></div>
          <div className="flex items-center gap-1">
            <GlobalAlertDrawer />
            <Button variant="ghost" size="icon" className="rounded-lg text-muted-foreground hover:bg-muted hover:text-foreground" onClick={toggleTheme} aria-label={dark ? "Use light theme" : "Use dark theme"}>{dark ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}</Button>
            <div className="mx-2 hidden h-6 w-px bg-border sm:block" />
            <DropdownMenu>
              <DropdownMenuTrigger asChild><Button variant="ghost" className="h-10 gap-2 rounded-lg px-2 hover:bg-muted" aria-label="Open user profile menu"><span className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary text-xs font-bold text-primary-foreground shadow-sm">MC</span><span className="hidden text-sm font-semibold sm:inline">{displayName}</span><ChevronDown className="h-3.5 w-3.5 text-muted-foreground" /></Button></DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-64 rounded-xl p-1.5 shadow-xl">
                <DropdownMenuLabel className="font-normal"><span className="block font-semibold text-foreground">{displayName}</span><span className="block truncate text-xs text-muted-foreground">{email}</span></DropdownMenuLabel>
                <DropdownMenuSeparator />
                <DropdownMenuItem onSelect={() => { setProfileSaved(false); setProfileOpen(true); }}><UserRound className="mr-2 h-4 w-4" />Profile settings</DropdownMenuItem>
                <DropdownMenuSeparator />
                <DropdownMenuItem className="text-destructive focus:text-destructive" onSelect={() => navigate("/login")}><LogOut className="mr-2 h-4 w-4" />Sign out</DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </header>
        <main className="w-full min-w-0 px-4 py-7 sm:px-6 lg:px-8 lg:py-10 xl:px-10">
          <div className="mx-auto w-full max-w-[1600px] min-w-0"><Outlet /></div>
        </main>
        <Dialog open={profileOpen} onOpenChange={setProfileOpen}>
          <DialogContent className="rounded-xl border-border/80 shadow-2xl sm:max-w-md"><DialogHeader><DialogTitle>Profile settings</DialogTitle><DialogDescription>Operator identity for this local workspace.</DialogDescription></DialogHeader>
            <form className="space-y-4" onSubmit={(event) => { event.preventDefault(); setProfileSaved(true); window.setTimeout(() => setProfileOpen(false), 650); }}>
              <div className="border-l-2 border-primary bg-muted/60 p-3"><p className="text-sm font-medium text-foreground">Control room operator</p><p className="text-xs text-muted-foreground">BRR-OT.LOCAL · Active session</p></div>
              <div className="space-y-2"><Label htmlFor="profile-name">Display name</Label><Input id="profile-name" value={displayName} onChange={(event) => setDisplayName(event.target.value)} required /></div>
              <div className="space-y-2"><Label htmlFor="profile-email">Email address</Label><Input id="profile-email" type="email" value={email} onChange={(event) => setEmail(event.target.value)} required /></div>
              {profileSaved && <p className="flex items-center gap-2 text-sm font-medium text-emerald-600 dark:text-emerald-400"><Check className="h-4 w-4" />Profile saved</p>}
              <DialogFooter><Button type="button" variant="outline" onClick={() => setProfileOpen(false)}>Cancel</Button><Button type="submit">Save changes</Button></DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </SidebarInset>
    </SidebarProvider>
  );
}

export { Layout };
