import "./styles.css";
import React from "react";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import Layout from "./components/Layout";
import FleetOverview from "./pages/FleetOverview";
import Assets from "./pages/Assets";
import AssetDiagnostics from "./pages/AssetDiagnostics";
import Login from "./pages/Login";
import AssetHealthSummary from "./pages/AssetHealthSummary";
import SpectralAnalytics from "./pages/SpectralAnalytics";
import UnitRiskMatrix from "./pages/UnitRiskMatrix";
import PrescriptiveAdvisories from "./pages/PrescriptiveAdvisories";
import ModelRetraining from "./pages/ModelRetraining";
import ModelEvaluation from "./pages/ModelEvaluation";
import Landing from "./pages/Landing";
import WorkOrderConfirmation from "./pages/WorkOrderConfirmation";
import HistorianConnections from "./pages/HistorianConnections";
import TagMapping from "./pages/TagMapping";
import AssetHierarchyBuilder from "./pages/AssetHierarchyBuilder";
import SecurityAudit from "./pages/SecurityAudit";
import SystemHealth from "./pages/SystemHealth";
import OperationsShiftLog from "./pages/OperationsShiftLog";

function App() {
  return (
    <BrowserRouter>

      <Routes>
        <Route element={<Layout />}>
                <Route path="/fleet-overview" element={<FleetOverview />} />
      <Route path="/assets" element={<Assets />} />
      <Route path="/assets/:assetId/diagnostics" element={<AssetDiagnostics />} />
      <Route path="/login" element={<Login />} />
      <Route path="/assets/:assetId/health-summary" element={<AssetHealthSummary />} />
      <Route path="/assets/:assetId/spectral-analytics" element={<SpectralAnalytics />} />
      <Route path="/operations/unit-risk-matrix" element={<UnitRiskMatrix />} />
      <Route path="/prescriptive-advisories" element={<PrescriptiveAdvisories />} />
      <Route path="/model-management/retraining" element={<ModelRetraining />} />
      <Route path="/model-management/evaluation" element={<ModelEvaluation />} />
      <Route path="/" element={<Landing />} />
      <Route path="/work-orders/confirmation" element={<WorkOrderConfirmation />} />
      <Route path="/admin/historian-connections" element={<HistorianConnections />} />
      <Route path="/admin/tag-mapping" element={<TagMapping />} />
      <Route path="/admin/asset-hierarchy-builder" element={<AssetHierarchyBuilder />} />
      <Route path="/admin/security-audit" element={<SecurityAudit />} />
      <Route path="/admin/system-health" element={<SystemHealth />} />
      <Route path="/operations/shift-log" element={<OperationsShiftLog />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;
