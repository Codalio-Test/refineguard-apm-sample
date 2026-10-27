# frozen_string_literal: true

class Role < ApplicationRecord
  ROLES = [ "admin", "reliability_engineer", "machinery_specialist", "maintenance_planner", "operations_superintendent" ].freeze

  has_many :user_roles, dependent: :destroy
  has_many :users, through: :user_roles

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
end
