import { useMemo, useState } from "react";
import { CheckCircle2, Download, Filter, KeyRound, Search, ShieldCheck, Users } from "lucide-react";
import { SeverityBadge } from "../components/SeverityBadge";
import { Badge } from "../components/ui/badge";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Input } from "../components/ui/input";
import { Progress } from "../components/ui/progress";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../components/ui/table";

const auditEvents = [
  { timestamp: "10:42:18", severity: "info", actor: "m.chen", role: "Reliability", action: "ACKNOWLEDGE", object: "INC-24018", host: "ENG-WS14", result: "Success" },
  { timestamp: "10:31:04", severity: "warning", actor: "svc.pi", role: "Service", action: "AUTH_RETRY", object: "PI Primary", host: "RG-NODE1", result: "Success" },
];

export default function SecurityAudit() {
  const [query, setQuery] = useState("");
  const [severity, setSeverity] = useState("all");
  const [range, setRange] = useState("24h");
  const [exported, setExported] = useState(false);

  const filteredEvents = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();
    return auditEvents.filter((event) => {
      const matchesSeverity = severity === "all" || event.severity === severity;
      const matchesQuery = !normalizedQuery || Object.values(event).some((value) => value.toLowerCase().includes(normalizedQuery));
      return matchesSeverity && matchesQuery;
    });
  }, [query, severity]);

  const handleExport = () => {
    setExported(true);
    window.setTimeout(() => setExported(false), 3000);
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
                <Select value={range} onValueChange={setRange}>
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
            {[["Operators", "Standard operations access", 24], ["Reliability engineers", "Diagnostics and advisory access", 8], ["Administrators", "Privileged system access", 3]].map(([role, description, count], index) => (
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
            <div className="flex items-end justify-between"><div><p className="text-3xl font-semibold tracking-tight">96%</p><p className="text-xs text-muted-foreground">Controls passing</p></div><Badge variant="outline" className="rounded-md border-emerald-300 bg-emerald-100 text-emerald-900 dark:border-emerald-800 dark:bg-emerald-950 dark:text-emerald-200">Verified</Badge></div>
            <Progress value={96} className="h-2" />
            <div className="grid gap-2 text-xs text-muted-foreground sm:grid-cols-2">
              {["Air-gap outbound deny", "Local LDAP binding", "Audit retention", "Certificate validity"].map((check) => <span key={check} className="flex items-center gap-2"><CheckCircle2 className="h-4 w-4 text-emerald-600 dark:text-emerald-400" />{check}</span>)}
            </div>
          </CardContent>
        </Card>
      </section>
    </div>
  );
}