# frozen_string_literal: true

# The IEC 62443 security event stream rendered by /admin/security-audit.
#
# Append-only by construction: no role holds `security_audit_events.store`,
# `.update` or `.destroy`, so the API can never write or mutate a row. Rows are
# produced server-side by Refineguard::SecurityAuditWriter, which chains each
# row to its predecessor via sha256(previous_hash + canonical payload).
class SecurityAuditEvent < Rhino::RhinoModel
  include Rhino::BelongsToOrganization

  belongs_to :user, class_name: "User", optional: true

  rhino_filters :user_id, :actor_name, :actor_role, :action_type, :entity_affected, :source_host, :severity, :result, :recorded_at, :tamper_proof_hash, :previous_hash
  rhino_sorts :user_id, :actor_name, :actor_role, :action_type, :entity_affected, :source_host, :severity, :result, :recorded_at, :tamper_proof_hash, :previous_hash, :created_at
  rhino_fields :id, :user_id, :actor_name, :actor_role, :action_type, :entity_affected, :source_host, :severity, :result, :recorded_at, :tamper_proof_hash, :previous_hash, :details_json, :created_at
  rhino_includes :user
  rhino_search :actor_name, :actor_role, :action_type, :entity_affected, :source_host
  rhino_default_sort "-recorded_at"

  validates :action_type, presence: true, length: { maximum: 255 }
  validates :recorded_at, presence: true
  validates :tamper_proof_hash, presence: true, length: { maximum: 255 }
  validates :actor_name, length: { maximum: 255 }, allow_nil: true
  validates :actor_role, length: { maximum: 255 }, allow_nil: true
  validates :entity_affected, length: { maximum: 255 }, allow_nil: true
  validates :source_host, length: { maximum: 255 }, allow_nil: true
  validates :severity, length: { maximum: 255 }, allow_nil: true
  validates :result, length: { maximum: 255 }, allow_nil: true
  validates :previous_hash, length: { maximum: 255 }, allow_nil: true

  # Recompute the chain hash for this row's canonical payload.
  def expected_hash
    Digest::SHA256.hexdigest("#{previous_hash}#{canonical_payload}")
  end

  def tamper_proof?
    tamper_proof_hash == expected_hash
  end

  def canonical_payload
    [
      organization_id,
      user_id,
      actor_name,
      actor_role,
      action_type,
      entity_affected,
      source_host,
      severity,
      result,
      recorded_at&.utc&.iso8601,
      details_json
    ].to_json
  end

  def rhino_computed_attributes
    {
      "tamper_proof" => tamper_proof?,
      "actor" => actor_name,
      "role" => actor_role,
      "object" => entity_affected,
      "host" => source_host,
      "timestamp" => recorded_at&.iso8601
    }
  end
end
