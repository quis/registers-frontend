require 'active_support/concern'

module FormValidations
  extend ActiveSupport::Concern
  included do
    validates :is_government, inclusion: { in: [true, false] }
    validates :email_gov, presence: true, if: -> { is_government }
    validates :department, presence: true, if: -> { is_government }
    validates :department, absence: true, unless: -> { is_government }
    validates :email_non_gov, presence: true, unless: -> { is_government }
    validates :non_gov_use_category, presence: true, unless: -> { is_government }
    validates :non_gov_use_category, absence: true, if: -> { is_government }
  end
end