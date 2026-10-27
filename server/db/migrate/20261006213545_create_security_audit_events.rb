# frozen_string_literal: true

class CreateSecurityAuditEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :security_audit_events do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, foreign_key: true, null: true
      t.string :actor_name, null: true
      t.string :actor_role, null: true
      t.string :action_type
      t.string :entity_affected, null: true
      t.string :source_host, null: true
      t.string :severity, null: true, default: "info"
      t.string :result, null: true, default: "Success"
      t.datetime :recorded_at
      t.string :tamper_proof_hash
      t.string :previous_hash, null: true
      t.json :details_json, null: true

      t.timestamps
    end
  end
end
