# frozen_string_literal: true

module Refineguard
  # the ≤50-tag batch validation harness and the
  # per-tag quality gate that blocks digital-twin activation.
  #
  # Each row reports success, the sample telemetry value and the round-trip
  # latency; a tag that is invalid, stale for more than 60 s, or reporting a bad
  # OPC quality flag produces a failure row.
  class TagValidationService
    MAX_TAGS_PER_BATCH = 50
    LATENCY_BUDGET_MS = 2000

    Row = Struct.new(:tag_path, :tag_id, :success, :value, :latency_ms, :quality_status,
                     :stale_seconds, :errors, keyword_init: true)

    Result = Struct.new(:rows, :duration_ms, :within_budget, :passed, :failed, keyword_init: true) do
      def success?
        failed.zero? && within_budget
      end
    end

    def initialize(organization:, tags: nil, tag_ids: nil)
      @organization = organization
      @tags = tags
      @tag_ids = tag_ids
    end

    def call
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      scoped = resolve_tags
      return too_many(scoped.length) if scoped.length > MAX_TAGS_PER_BATCH

      rows = scoped.map { |tag| validate(tag) }
      duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

      Result.new(
        rows: rows,
        duration_ms: duration,
        within_budget: duration <= LATENCY_BUDGET_MS,
        passed: rows.count(&:success),
        failed: rows.count { |r| !r.success }
      )
    end

    private

    def resolve_tags
      if @tags.present?
        Array(@tags).first(MAX_TAGS_PER_BATCH + 1).filter_map do |entry|
          built = build_from_payload(entry)
          built
        end
      else
        scope = HistorianTag.where(organization: @organization)
        scope = scope.where(id: @tag_ids) if @tag_ids.present?
        scope.includes(:historian_connector).limit(MAX_TAGS_PER_BATCH + 1).to_a
      end
    end

    # A tag supplied inline (\"connect and test\") is transient — never persisted.
    def build_from_payload(entry)
      attrs = entry.respond_to?(:to_unsafe_h) ? entry.to_unsafe_h : entry.to_h
      attrs = attrs.transform_keys(&:to_s)

      if attrs["id"].present? && (existing = HistorianTag.where(organization: @organization)
                                                            .find_by(id: attrs["id"]))
        existing
      else
        HistorianTag.new(attrs.slice(*HistorianTag.column_names))
      end
    end

    def validate(tag)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      errors = []

      errors << "tag path is required" if tag.tag_path.blank?
      errors << "historian_type must be OSIsoft_PI, Honeywell_PHD or Yokogawa_Exaquantum" \
        unless HistorianTag::HISTORIAN_TYPES.include?(tag.historian_type.to_s)
      errors << "tag is stale (#{tag.computed_stale_seconds}s > #{HistorianTag::STALE_THRESHOLD_SECONDS}s)" if tag.stale?
      errors << "quality flag is bad (#{tag.quality_status})" if tag.bad_quality?
      errors << "tag is not persisted" if tag.new_record? && tag.id.nil? && tag.errors.any?

      value = tag.last_value
      value = tag.telemetry_records.order(recorded_at: :desc).limit(1).pick(:recorded_value) if value.nil?

      latency = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

      Row.new(
        tag_path: tag.tag_path,
        tag_id: tag.id,
        success: errors.empty?,
        value: value,
        latency_ms: latency,
        quality_status: tag.quality_status,
        stale_seconds: tag.computed_stale_seconds,
        errors: errors
      )
    rescue StandardError => e
      Row.new(tag_path: tag&.tag_path, tag_id: tag&.id, success: false, errors: [ e.message ])
    end

    def too_many(count)
      Result.new(
        rows: [ Row.new(tag_path: nil, tag_id: nil, success: false,
                       errors: [ "A batch may contain at most #{MAX_TAGS_PER_BATCH} tags (got #{count})" ]) ],
        duration_ms: 0, within_budget: true, passed: 0, failed: 1
      )
    end
  end
end
