# Site-wide switches an admin can change without a deploy. The list of settings
# (name, type, default, limits) lives here in code; only values that differ from
# the default are stored. Reading a setting never fails: an unknown or missing
# value falls back to its default.
#
#   SiteSetting.get('signups_enabled')          # => true
#   SiteSetting.update_values('homepage_streams_limit' => '3')
class SiteSetting < ApplicationRecord
  CACHE_KEY = 'site_settings/values'.freeze

  DEFINITIONS = Definitions::ALL

  validates :key, presence: true, uniqueness: true, inclusion: { in: DEFINITIONS.keys }

  after_commit :clear_cache

  # ---- reading ----

  def self.get(key)
    definition = definition!(key)
    stored = stored_values[definition.key]
    stored.nil? ? definition.default : cast(definition, stored)
  end

  # Every setting, typed, defaults filled in.
  def self.values
    DEFINITIONS.keys.index_with { |key| get(key) }
  end

  def self.definition!(key)
    DEFINITIONS.fetch(key.to_s) { raise ArgumentError, "unknown setting: #{key.inspect}" }
  end

  def self.groups
    DEFINITIONS.values.group_by(&:group)
  end

  # ---- writing ----

  # Validates every submitted value first and saves nothing unless all are valid.
  # Returns a Result: `changes` is { key => [old, new] } for values that actually
  # changed, `errors` is { key => message }.
  Result = Struct.new(:changes, :errors) do
    def success?
      errors.empty?
    end
  end

  def self.update_values(submitted)
    parsed, errors = parse_submitted(submitted)
    return Result.new({}, errors) if errors.any?

    changes = parsed.filter_map { |key, value| [key, [get(key), value]] if get(key) != value }.to_h
    transaction do
      changes.each { |key, (_old, new_value)| find_or_initialize_by(key: key).update!(value: serialize(new_value)) }
    end
    Result.new(changes, {})
  end

  def self.parse_submitted(submitted)
    values = {}
    errors = {}
    submitted.to_h.slice(*DEFINITIONS.keys).each do |key, raw|
      values[key] = parse(DEFINITIONS.fetch(key), raw)
    rescue ArgumentError => e
      errors[key] = e.message
    end
    [values, errors]
  end

  # Turns a form value into a typed one, or raises ArgumentError with a message
  # fit to show next to the field.
  def self.parse(definition, raw)
    case definition.type
    when :boolean then ActiveModel::Type::Boolean.new.cast(raw) || false
    when :integer then parse_integer(definition, raw)
    when :enum then parse_enum(definition, raw)
    else parse_string(definition, raw)
    end
  end

  def self.parse_integer(definition, raw)
    number = Integer(raw.to_s.strip, 10)
    raise ArgumentError, "must be between #{definition.range.min} and #{definition.range.max}" unless definition.range.cover?(number)

    number
  rescue ArgumentError, TypeError
    raise ArgumentError, "must be a whole number between #{definition.range.min} and #{definition.range.max}"
  end

  def self.parse_enum(definition, raw)
    value = raw.to_s
    raise ArgumentError, "must be one of: #{definition.choices.join(', ')}" unless definition.choices.include?(value)

    value
  end

  def self.parse_string(definition, raw)
    value = raw.to_s.strip
    raise ArgumentError, "must be at most #{definition.max_length} characters" if value.length > definition.max_length

    value
  end

  def self.cast(definition, stored)
    case definition.type
    when :boolean then stored == 'true'
    when :integer then Integer(stored, 10)
    else stored
    end
  rescue ArgumentError, TypeError
    definition.default # a hand-edited or corrupt row never breaks the site
  end

  def self.serialize(value)
    value.to_s
  end

  # { 'key' => 'raw string' } for every stored row; cached so the banner,
  # maintenance check and home page don't each hit the database.
  def self.stored_values
    Rails.cache.fetch(CACHE_KEY) { pluck(:key, :value).to_h }
  end

  def self.clear_cache
    Rails.cache.delete(CACHE_KEY)
  end

  private_class_method :parse_submitted, :parse, :parse_integer, :parse_enum, :parse_string, :cast, :serialize

  private

  def clear_cache
    self.class.clear_cache
  end
end
