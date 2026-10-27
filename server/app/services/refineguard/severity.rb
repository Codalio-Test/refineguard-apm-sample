# frozen_string_literal: true

module Refineguard
  # The single source of truth for the ISO 10816 / API 670 state vocabulary.
  #
  # The locked UI prototype renders `<SeverityBadge severity=.../>`, which only
  # understands `critical | warning | healthy | info`. The ISO state is retained
  # on `health_state` / `severity` columns for filtering and PRD traceability, so
  # both keys are always emitted and this module translates between them.
  module Severity
    # ISO state (or severity label) => locked badge key.
    BADGE = {
      "trip" => "critical",
      "alarm" => "critical",
      "critical" => "critical",
      "alert" => "warning",
      "warning" => "warning",
      "degraded" => "warning",
      "advisory" => "warning",
      "normal" => "healthy",
      "healthy" => "healthy",
      "good" => "healthy",
      "info" => "info"
    }.freeze

    # Locked badge key => the human label the prototype prints in tables.
    LABEL = {
      "critical" => "Critical",
      "warning" => "Advisory",
      "healthy" => "Normal",
      "info" => "Info"
    }.freeze

    BADGE_ORDER = { "critical" => 0, "warning" => 1, "healthy" => 2, "info" => 3 }.freeze

    # @param state [String, nil] an ISO health state (Normal/Alert/Alarm/Trip) or
    #   a severity label (critical/warning/healthy/info).
    # @return [String] one of critical|warning|healthy|info
    def self.badge(state, default: "info")
      BADGE.fetch(state.to_s.strip.downcase, default)
    end

    # @return [String] the human-readable label for a badge key.
    def self.label(badge_key)
      LABEL.fetch(badge_key.to_s, "Info")
    end

    # Sort helper: lower is more severe.
    def self.rank(badge_key)
      BADGE_ORDER.fetch(badge_key.to_s, 99)
    end
  end
end
