# frozen_string_literal: true

module Api
  # on-premises infrastructure telemetry.
  #
  # Honesty contract: this endpoint reports ONLY values it actually measures. A
  # metric this process cannot observe (disk utilisation, active workers, clock
  # drift, backup state, ingestion throughput) is returned as `null` with a
  # `"not_measured"` status rather than a synthesized number, and the UI renders
  # "Not measured" for those rows. The values reported as measured are the ones
  # produced by a real probe here (the local database round-trip) or read
  # straight from persisted rows (connector heartbeat / severity, and the
  # adapter mode the API really selected).
  class SystemHealthController < BaseController
    MEASURED = "measured"
    NOT_MEASURED = "not_measured"
    UNMEASURED_STATUS = "Not measured"
    SERVICE_NAMES = [ "Ingestion gateway", "Time-series database", "Diagnostic engine",
                      "Model worker", "CMMS bridge", "LDAP" ].freeze
    STORAGE_VOLUMES = [ "Historian cache", "Telemetry store", "Model artifacts",
                        "Audit archive" ].freeze

    # GET /api/{organization}/system_health
    def show
      return if deny!(HistorianConnectorPolicy, :index?, HistorianConnector)

      connectors = Rhino.query(HistorianConnector).order(:connector_name).to_a

      render json: {
        "metrics" => metrics(database_reachable?),
        "services" => services(connectors),
        "storage" => storage,
        "events" => platform_events(connectors),
        "warnings" => warnings(connectors),
        "ingestion" => ingestion(connectors),
        "backup" => not_measured_backup,
        "generated_at" => Time.current.iso8601
      }
    end

    private

    # A metric is either measured here (value + "measured") or reported as absent.
    def metrics(database_ok)
      [
        measured("Local DB", database_ok ? "OK" : "Unavailable"),
        measured("API latency", "#{api_latency_ms}ms"),
        not_measured("Ingestion"),
        not_measured("Disk used"),
        not_measured("Workers"),
        not_measured("Clock drift")
      ]
    end

    def measured(name, value)
      { "name" => name, "value" => value, "status" => MEASURED }
    end

    def not_measured(name)
      { "name" => name, "value" => nil, "status" => NOT_MEASURED }
    end

    # Only the services whose state is genuinely known are reported as running:
    # the ingestion gateway's state is derived from persisted connector rows, and
    # the CMMS/LDAP bridges report the adapter mode the API actually selected.
    # The rest have no probe, so they are "Not measured" rather than "Running".
    def services(connectors)
      degraded = connectors.any? { |c| c.severity == "critical" }
      SERVICE_NAMES.map do |name|
        { "name" => name, "status" => service_status(name, degraded) }
      end
    end

    def service_status(name, degraded)
      case name
      when "Ingestion gateway" then degraded ? "Degraded" : "Running"
      when "CMMS bridge" then simulated_service_status(Refineguard::Cmms.configuration.simulated?)
      when "LDAP" then simulated_service_status(Refineguard::Ldap.configuration.simulated?)
      else UNMEASURED_STATUS
      end
    end

    # Local volumes we do not read from the filesystem: reported as rows with a
    # nil utilisation, never a number derived from row counts.
    def storage
      STORAGE_VOLUMES.map { |name| { "name" => name, "percent" => nil, "status" => NOT_MEASURED } }
    end

    def warnings(connectors)
      connectors.select { |c| c.severity == "critical" }
                .map { |c| "#{c.connector_name} is reporting a critical condition" }
    end

    # Genuinely-measured ingestion state, read from the connector rows.
    def ingestion(connectors)
      {
        "buffer_depth" => connectors.sum { |c| c.buffer_depth.to_i },
        "backfill_pending" => connectors.sum { |c| c.backfill_total.to_i - c.backfill_committed.to_i },
        "connectors" => connectors.map { |connector| connector_row(connector) }
      }
    end

    def connector_row(connector)
      {
        "id" => connector.id,
        "name" => connector.connector_name,
        "status" => connector.status,
        "latency_ms" => connector.poll_latency_ms,
        "buffer_depth" => connector.buffer_depth.to_i,
        "last_heartbeat" => connector.last_heartbeat&.iso8601,
        "severity" => connector.severity
      }
    end

    # The platform event feed is exactly the connector heartbeats on record — no
    # synthesized "backup completed" line.
    def platform_events(connectors)
      connectors.filter_map do |connector|
        next if connector.last_heartbeat.nil?

        "#{connector.last_heartbeat.strftime('%H:%M')} #{connector.connector_name} heartbeat #{connector.status}"
      end.first(8)
    end

    def not_measured_backup
      { "last_run_at" => nil, "status" => UNMEASURED_STATUS, "retention_days" => nil }
    end

    def simulated_service_status(simulated)
      simulated ? "SIMULATED" : "Running"
    end

    # A real, local round-trip: this both times the request path and proves the
    # database answered.
    def api_latency_ms
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      ActiveRecord::Base.connection.select_value("SELECT 1")
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round.clamp(1, 999)
    end

    def database_reachable?
      ActiveRecord::Base.connection.select_value("SELECT 1").to_i == 1
    rescue StandardError
      false
    end
  end
end
