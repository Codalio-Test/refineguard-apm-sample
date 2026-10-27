import json, urllib.request, urllib.error

BASE = "https://work-2-heoeegtcgjvftdxl.prod-runtime.all-hands.dev"
ORG = "demo-org"


def req(method, path, token=None, body=None):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, method=method)
    r.add_header("Content-Type", "application/json")
    if token:
        r.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            return resp.status, resp.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()
    except Exception as e:
        return -1, str(e)


USERS = {
    "admin": "administrator@example.com",
    "planner": "maintenance_planner@example.com",
    "engineer": "reliability_engineer@example.com",
    "specialist": "machinery_specialist@example.com",
    "superintendent": "operations_superintendent@example.com",
    "viewer": "viewer@example.com",
}

tokens = {}
for role, email in USERS.items():
    st, body = req("POST", "/api/auth/login", body={"email": email, "password": "password"})
    tok = json.loads(body).get("token") if st == 200 else None
    tokens[role] = tok
    print("login %-15s %s token=%s" % (role, st, "yes" if tok else "NO"))


def first_id(collection):
    st, body = req("GET", "/api/%s/%s?per_page=1" % (ORG, collection), token=tokens["admin"])
    try:
        rows = json.loads(body)["data"]
        return rows[0]["id"] if rows else None
    except Exception:
        return None


adv = first_id("prescriptive_advisories")
inc = first_id("diagnostic_incidents")
con = first_id("historian_connectors")
bas = first_id("model_baselines")
print("ids: advisory=%s incident=%s connector=%s baseline=%s" % (adv, inc, con, bas))
print()


def check(label, method, path, allowed, forbidden, body=None):
    sa, ba = req(method, path, token=tokens[allowed], body=body)
    sf, bf = req(method, path, token=tokens[forbidden], body=body)

    def short(s):
        return s[:110].replace("\n", " ") if s else ""

    print(label)
    print("   ALLOWED   %-15s -> %s  %s" % (allowed, sa, short(ba)))
    print("   FORBIDDEN %-15s -> %s  %s" % (forbidden, sf, short(bf)))


check("GET system_health (gate: historian_connectors.index)", "GET", "/api/%s/system_health" % ORG, "admin", "planner")
check("GET dashboard/fleet_overview (gate: assets.index)", "GET", "/api/%s/dashboard/fleet_overview" % ORG, "admin", "viewer")
check("GET dashboard/active_anomalies (gate: assets.index)", "GET", "/api/%s/dashboard/active_anomalies" % ORG, "admin", "viewer")
check("GET dashboard/unit_risk_matrix (gate: assets.index)", "GET", "/api/%s/dashboard/unit_risk_matrix" % ORG, "admin", "viewer")
check("GET security_audit_events/export (gate: index?)", "GET", "/api/%s/security_audit_events/export?format=json" % ORG, "admin", "specialist")
check("POST assets/validate_hierarchy (gate: assets.index)", "POST", "/api/%s/assets/validate_hierarchy" % ORG, "admin", "viewer", body={})
check("POST assets/import (gate: assets.create)", "POST", "/api/%s/assets/import" % ORG, "specialist", "planner", body={"filename": "x.csv", "import": ""})
check("POST historian_tags/import (gate: historian_tags.create)", "POST", "/api/%s/historian_tags/import" % ORG, "admin", "engineer", body={"filename": "x.csv", "import": ""})
check("POST historian_tags/validate_batch (gate: index?)", "POST", "/api/%s/historian_tags/validate_batch" % ORG, "admin", "viewer", body={})

if con:
    check("POST historian_connectors/:id/test_connection (gate: update?+admin)", "POST", "/api/%s/historian_connectors/%s/test_connection" % (ORG, con), "admin", "engineer", body={})
if bas:
    check("POST model_baselines/:id/train (gate: train?)", "POST", "/api/%s/model_baselines/%s/train" % (ORG, bas), "specialist", "engineer", body={})
    check("POST model_baselines/:id/promote (gate: promote?)", "POST", "/api/%s/model_baselines/%s/promote" % (ORG, bas), "specialist", "engineer", body={})
if inc:
    check("POST diagnostic_incidents/:id/acknowledge (gate: acknowledge?)", "POST", "/api/%s/diagnostic_incidents/%s/acknowledge" % (ORG, inc), "engineer", "specialist", body={})
    check("POST diagnostic_incidents/:id/sign_off (gate: sign_off?)", "POST", "/api/%s/diagnostic_incidents/%s/sign_off" % (ORG, inc), "specialist", "engineer", body={"finding": {}})
if adv:
    check("POST prescriptive_advisories/:id/evaluate_standby (gate: evaluate_standby?)", "POST", "/api/%s/prescriptive_advisories/%s/evaluate_standby" % (ORG, adv), "superintendent", "specialist", body={})
    check("POST prescriptive_advisories/:id/approve_derate valid 0", "POST", "/api/%s/prescriptive_advisories/%s/approve_derate" % (ORG, adv), "superintendent", "planner", body={"throttle_percentage": 0})
    check("POST prescriptive_advisories/:id/approve_derate valid 100", "POST", "/api/%s/prescriptive_advisories/%s/approve_derate" % (ORG, adv), "superintendent", "planner", body={"throttle_percentage": 100})
    check("POST prescriptive_advisories/:id/approve_derate invalid 250 (expect 422)", "POST", "/api/%s/prescriptive_advisories/%s/approve_derate" % (ORG, adv), "superintendent", "planner", body={"throttle_percentage": 250})
    check("POST prescriptive_advisories/:id/approve_derate invalid -40 (expect 422)", "POST", "/api/%s/prescriptive_advisories/%s/approve_derate" % (ORG, adv), "superintendent", "planner", body={"throttle_percentage": -40})
    check("POST prescriptive_advisories/:id/dispatch_work_order (gate: dispatch_work_order?)", "POST", "/api/%s/prescriptive_advisories/%s/dispatch_work_order" % (ORG, adv), "planner", "superintendent", body={"priority": "Priority 2 - Urgent (Within 7 Days)", "cmms_type": "SAP PM"})

print()
print("SPA pages (client-rendered; expect 200 index.html):")
for page in ["/", "/login", "/fleet-overview", "/assets", "/operations/unit-risk-matrix",
             "/operations/shift-log", "/prescriptive-advisories", "/work-orders/confirmation",
             "/model-management/retraining", "/admin/historian-connections", "/admin/tag-mapping",
             "/admin/security-audit", "/admin/system-health", "/auth/signin"]:
    print("   %-32s -> %s" % (page, req("GET", page)[0]))

print()
print("unauthenticated / bad org / missing id:")
print("   no token custom     ->", req("GET", "/api/%s/system_health" % ORG)[0])
print("   bad org             ->", req("GET", "/api/nope-org/system_health", token=tokens["admin"])[0])
print("   non-member org      ->", req("GET", "/api/runtime-other-org/system_health", token=tokens["admin"])[0])
print("   missing id custom   ->", req("POST", "/api/%s/prescriptive_advisories/99999999/approve_derate" % ORG, token=tokens["superintendent"], body={"throttle_percentage": 50})[0])
print("   missing id sign_off ->", req("POST", "/api/%s/diagnostic_incidents/99999999/sign_off" % ORG, token=tokens["specialist"], body={"finding": {}})[0])
