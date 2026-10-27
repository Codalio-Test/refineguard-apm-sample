# frozen_string_literal: true

class CreateHistorianConnectors < ActiveRecord::Migration[8.0]
  def change
    create_table :historian_connectors do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :connector_name
      t.string :historian_type
      t.string :protocol_type, null: true
      t.string :endpoint_url, null: true
      t.string :server_address, null: true
      t.integer :port, null: true
      t.integer :polling_interval_seconds, null: true, default: 5
      t.string :status, default: "Connected"
      t.datetime :last_heartbeat, null: true
      t.integer :poll_latency_ms, null: true
      t.bigint :buffer_depth, null: true
      t.integer :backfill_queue, null: true
      t.bigint :backfill_committed, null: true
      t.bigint :backfill_total, null: true
      t.boolean :ring_buffer_enabled, null: true, default: true
      t.integer :connection_timeout_ms, null: true, default: 3000
      t.string :credentials_ref, null: true
      t.datetime :discarded_at
      t.index :discarded_at
      t.timestamps
    end
  end
end
