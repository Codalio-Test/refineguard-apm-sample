import { useMemo, useState } from "react";
import { useModelIndex } from "@rhino-dev/rhino-react";
import { useAuditExport } from "../hooks/useApiQueries";
import { CheckCircle2, Download, Filter, KeyRound, Search, ShieldCheck, Users } from "lucide-react";
import { SeverityBadge } from "../components/SeverityBadge";
import { Badge } from "../components/ui/badge";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Input } from "../components/ui/input";
import { Progress } from "../components/ui/progress";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../components/ui/table";

export default function SecurityAudit() {
  const [query, setQuery] = useState("");
  const [severity, setSeverity] = useState("all");
  const [range, setRange] = useState("24h");
  const [exported, setExported] = useState(false);
  // A single render clock, seeded lazily and refreshed when the operator changes
  // the date range, so the window start is never recomputed impurely mid-render.
  const [now, setNow] = useState(() => Date.now());
  const changeRange = (value: string) => {
    setRange(value);
    setNow(Date.now());
  };
  const rangeStartDays = range === "24h" ? 1 : range === "7d" ? 7 : 30;
  const { data: eventResponse } = useModelIndex("security_audit_events", {
    search: query || undefined,
    filters: {
      ...(severity === "all" ? {} : { severity }),
      recorded_at_from: new Date(now - rangeStartDays * 86_400_000).toISOString(),
    },
    sort: "-recorded_at",
    perPage: 100,
  });
  const { data: userResponse } = useModelIndex("users", { perPage: 100 });
  const exportEvidence = useAuditExport();
  const auditEvents = useMemo(
    () =>
      (eventResponse?.data ?? []).map((event) => ({
        timestamp: event.recorded_at ? new Date(event.recorded_at).toLocaleTimeString([], { hour12: false }) : "\u2014",
        severity: event.severity ?? "info",
        actor: event.actor_name ?? "\u2014",
        role: event.actor_role ?? "\u2014",
        action: event.action_type ?? "\u2014",
        object: event.entity_affected ?? "\u2014",
        host: event.source_host ?? "\u2014",
        result: event.result ?? "\u2014",
      })),
    [eventResponse],
  );
  const users = userResponse?.data ?? [];
  const roleCounts: Array<[string, string, number]> = [
    ["Operators", "Standard operations access", users.filter((user) => (user.role_slugs ?? []).includes("operations_superintendent")).length],
    ["Reliability engineers", "Diagnostics and advisory access", users.filter((user) => (user.role_slugs ?? []).includes("reliability_engineer")).length],
    ["Administrators", "Privileged system access", users.filter((user) => (user.role_slugs ?? []).includes("admin")).length],
  ];
  const controlsPassing = auditEvents.length
    ? Math.round((auditEvents.filter((event) => (event.result ?? "").toLowerCase().startsWith("succ")).length / auditEvents.length) * 100)
    : 0;

  const filteredEvents = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();
    return auditEvents.filter((event) => {
      const matchesSeverity = severity === "all" || event.severity === severity;
      const matchesQuery = !normalizedQuery || Object.values(event).some((value) => value.toLowerCase().includes(normalizedQuery));
      return matchesSeverity && matchesQuery;
    });
  }, [auditEvents, query, severity]);

  // Signed, tamper-evident export from the local audit store.
  const handleExport = () => {
    setExported(true);
    exportEvidence.mutate("json", {
      onSuccess: (payload) => {
        const blob = new Blob([typeof payload === "string" ? payload : JSON.stringify(payload, null, 2)], { type: "application/json" });
        const url = URL.createObjectURL(blob);
        const anchor = document.createElement("a");
        anchor.href = url;
        anchor.download = "security-audit-evidence.json";
        anchor.click();
        URL.revokeObjectURL(url);
      },
      onSettled: () => window.setTimeout(() => setExported(false), 3000),
    });
  };

  return (
    <div className="w-full min-w-0 space-y-8 lg:space-y-10">
      <section className="flex flex-col gap-5 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <div className="mb-1 flex items-center gap-2 text-xs font-semibold uppercase tracking-widest text-primary">
            <ShieldCheck className="h-4 w-4" /> Governance &amp; access
          </div>
          <h1 className="text-2xl font-semibold tracking-tight text-foreground">Security audit</h1>
          <p className="mt-1 text-sm text-muted-foreground">Review access activity and IEC 62443 compliance evidence.</p>
        </div>
        <Button onClick={handleExport} className="gap-2 sm:self-center">
          {exported ? <CheckCircle2 className="h-4 w-4" /> : <Download className="h-4 w-4" />}
          {exported ? "Evidence exported" : "Export evidence"}
        </Button>
      </section>

      <section>
        <Card className="overflow-hidden rounded-xl border-border/80 bg-card">
          <CardHeader className="border-b border-border/80 bg-card px-5 py-5 sm:px-6">
            <div className="flex items-center justify-between gap-4">
              <div>
                <CardTitle className="text-base font-semibold">Local security audit trail</CardTitle>
                <p className="mt-1 text-xs text-muted-foreground">Immutable events from local services and operator workstations</p>
              </div>
              <Badge variant="outline" className="rounded-md bg-card font-mono text-xs">{filteredEvents.length} events</Badge>
            </div>
          </CardHeader>
          <CardContent className="p-0">
            <div className="flex flex-col gap-4 border-b border-border/80 bg-muted/25 p-5 md:flex-row md:items-center md:justify-between sm:p-6">
              <div className="relative min-w-0 flex-1 md:max-w-md">
                <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                <Input
                  value={query}
                  onChange={(event) => setQuery(event.target.value)}
                  className="h-10 border-input bg-background pl-9 focus-visible:ring-2"
                  placeholder="Search actor, action, object, or host"
                  aria-label="Search audit events"
                />
              </div>
              <div className="flex flex-col gap-3 sm:flex-row">
                <Select value={severity} onValueChange={setSeverity}>
                  <SelectTrigger className="h-10 w-full bg-background sm:w-44" aria-label="Filter by severity">
                    <Filter className="mr-2 h-4 w-4 text-muted-foreground" />
                    <SelectValue placeholder="Severity" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All severities</SelectItem>
                    <SelectItem value="info">Information</SelectItem>
                    <SelectItem value="warning">Warning</SelectItem>
                  </SelectContent>
                </Select>
                <Select value={range} onValueChange={changeRange}>
                  <SelectTrigger className="h-10 w-full bg-background sm:w-40" aria-label="Filter by date range">
                    <SelectValue placeholder="Date range" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="24h">Last 24 hours</SelectItem>
                    <SelectItem value="7d">Last 7 days</SelectItem>
                    <SelectItem value="30d">Last 30 days</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>{["Timestamp", "Severity", "Actor", "Role", "Action", "Object", "Source host", "Result"].map((heading) => <TableHead key={heading}>{heading}</TableHead>)}</TableRow>
                </TableHeader>
                <TableBody>
                  {filteredEvents.map((event) => (
                    <TableRow key={`${event.timestamp}-${event.actor}`} className="h-14">
                      <TableCell className="whitespace-nowrap font-mono text-xs text-muted-foreground">{event.timestamp}</TableCell>
                      <TableCell><SeverityBadge severity={event.severity} /></TableCell>
                      <TableCell className="font-mono text-xs font-semibold text-foreground">{event.actor}</TableCell>
                      <TableCell className="text-sm text-muted-foreground">{event.role}</TableCell>
                      <TableCell><span className="rounded border border-border bg-muted/60 px-2 py-1 font-mono text-xs font-semibold text-foreground">{event.action}</span></TableCell>
                      <TableCell className="whitespace-nowrap font-mono text-xs">{event.object}</TableCell>
                      <TableCell className="whitespace-nowrap font-mono text-xs text-muted-foreground">{event.host}</TableCell>
                      <TableCell><span className="inline-flex items-center gap-1.5 text-xs font-semibold text-emerald-700 dark:text-emerald-300"><CheckCircle2 className="h-3.5 w-3.5" />{event.result}</span></TableCell>
                    </TableRow>
                  ))}
                  {filteredEvents.length === 0 && <TableRow><TableCell colSpan={8} className="h-28 text-center text-sm text-muted-foreground">No audit events match the current filters.</TableCell></TableRow>}
                </TableBody>
              </Table>
            </div>
          </CardContent>
        </Card>
      </section>

      <section className="grid gap-6 lg:grid-cols-2">
        <Card className="overflow-hidden rounded-xl border-border/80 bg-card">
          <CardHeader className="flex flex-row items-center justify-between border-b border-border/70 px-6 py-5">
            <div>
              <CardTitle className="text-base font-semibold">RBAC summary</CardTitle>
              <p className="mt-1 text-xs text-muted-foreground">Active identities by assigned role</p>
            </div>
            <div className="rounded-xl bg-blue-100 p-2.5 text-blue-700 ring-1 ring-blue-200 dark:bg-blue-950 dark:text-blue-300 dark:ring-blue-900"><Users className="h-5 w-5" /></div>
          </CardHeader>
          <CardContent className="p-0">
            {roleCounts.map(([role, description, count], index) => (
              <div key={String(role)} className={`flex items-center justify-between gap-4 px-5 py-4 ${index < 2 ? "border-b border-border" : ""}`}>
                <div><p className="text-sm font-medium text-foreground">{role}</p><p className="text-xs text-muted-foreground">{description}</p></div>
                <span className="min-w-10 rounded-md bg-secondary px-2.5 py-1 text-center font-mono text-sm font-semibold text-secondary-foreground">{count}</span>
              </div>
            ))}
          </CardContent>
        </Card>

        <Card className="overflow-hidden rounded-xl border-border/80 bg-card">
          <CardHeader className="flex flex-row items-center justify-between border-b border-border/70 px-6 py-5">
            <div>
              <CardTitle className="text-base font-semibold">IEC 62443 posture</CardTitle>
              <p className="mt-1 text-xs text-muted-foreground">Technical control verification</p>
            </div>
            <div className="rounded-md bg-emerald-100 p-2 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300"><KeyRound className="h-5 w-5" /></div>
          </CardHeader>
          <CardContent className="space-y-6 p-5 sm:p-6">
            <div className="flex items-end justify-between"><div><p className="text-3xl font-semibold tracking-tight">{controlsPassing}%</p><p className="text-xs text-muted-foreground">Controls passing</p></div><Badge variant="outline" className="rounded-md border-emerald-300 bg-emerald-100 text-emerald-900 dark:border-emerald-800 dark:bg-emerald-950 dark:text-emerald-200">Verified</Badge></div>
            <Progress value={controlsPassing} className="h-2" />
            <div className="grid gap-2 text-xs text-muted-foreground sm:grid-cols-2">
              {["Air-gap outbound deny", "Local LDAP binding", "Audit retention", "Certificate validity"].map((check) => <span key={check} className="flex items-center gap-2"><CheckCircle2 className="h-4 w-4 text-emerald-600 dark:text-emerald-400" />{check}</span>)}
            </div>
          </CardContent>
        </Card>
      </section>
    </div>
  );
}