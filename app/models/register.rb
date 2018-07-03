class Register < ApplicationRecord
  before_validation :set_slug

  CURRENT_PHASES = %w[Backlog Discovery Alpha Beta].freeze

  ordered_phases = "CASE register_phase #{CURRENT_PHASES.reverse.each_with_index.map { |p, i| "WHEN '#{p}' THEN #{i}" }.join(' ')} END"

  validates_presence_of :name, :register_phase
  validates_uniqueness_of :name
  validates :slug, uniqueness: true

  scope :by_name, -> { order name: :asc }
  scope :by_popularity, -> { order position: :asc }
  scope :sort_by_phase_name_asc, -> { order(ordered_phases) }
  scope :has_records, -> { where(id: Record.select(:register_id)) }
  scope :available, -> { has_records.or(Register.where(register_phase: 'Backlog')) }
  scope :in_beta, -> { where(register_phase: 'Beta') }
  scope :search_registers, lambda { |search_term|
                             if search_term.present?
                               Register.select('registers.*', "records.data")
                                       .joins("LEFT JOIN records ON records.key = 'register:' || registers.slug")
                                       .where("name ILIKE ? OR cast(data->'text' as varchar) ILIKE ?", "%#{sanitize_sql_like(search_term)}%", "%#{sanitize_sql_like(search_term)}%")
                             end
                           }
  scope :sort_registers, ->(sort_by) { sort_by == 'name' ? by_name : by_popularity }
  scope :featured, -> { where(featured: true) }
  scope :not_featured, -> { where(featured: false) }

  has_many :entries, dependent: :destroy
  has_many :records, dependent: :destroy

  def register_last_updated
    Record.select('timestamp')
      .where(register_id: id, entry_type: 'user')
      .order(timestamp: :desc)
      .first[:timestamp]
      .to_s
  end

  def register_description
    Record.where(register_id: id, key: "register:#{slug}")
    .pluck("data -> 'text' as text")
    .first
  end

  def register_fields
    ordered_field_keys = fields_array.map { |f| "field:#{f}" }
    Record.where(register_id: id, key: ordered_field_keys)
          .order("position(key::text in '#{ordered_field_keys.join(',')}')")
          .map { |entry| entry[:data] }
  end

  def links_to
    linked_register_names = register_fields.select { |f| f['register'] && f['register'] != slug }.map { |f| f['register'] }
    Register.where(slug: linked_register_names)
  end

  def links_from
    Register.where.not(id: id)
    .joins(:records)
    .where(records: { entry_type: 'system' })
    .where("data->>'register' = ?", slug)
  end

  def register_authority
    Register.find_by(slug: 'government-organisation')&.records&.find_by(key: authority)
  end

  def number_of_records
    Record.where(register_id: id, entry_type: 'user').count
  end

  def register_name
    register_phase != 'Backlog' &&
      Record.where(register_id: id, entry_type: 'system', key: 'register-name')
            .pluck("data -> 'register-name' as register_name").first || name
  end

private

  def set_slug
    self.slug = name.try(:parameterize)
    self.slug += "-#{self.class.where(slug: slug).count}" if self.class.where(slug: slug).where.not(id: id).exists?
    slug
  end
end
