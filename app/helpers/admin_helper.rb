module AdminHelper
  def admin_time(time)
    return '—' if time.nil?

    tag.time(time.strftime('%-d %b %Y, %H:%M'), datetime: time.iso8601, title: time.iso8601)
  end

  def admin_ago(time, never: 'never')
    time ? "#{time_ago_in_words(time)} ago" : never
  end

  # The current list (same filters and sort) at a different page, for Previous / Next links.
  def page_url(page)
    "#{request.path}?#{request.query_parameters.merge('page' => page).to_query}"
  end

  # An audit entry's details as one readable line: "email: a@x.com → b@x.com; reason: spam".
  def audit_details(entry)
    entry.details.flat_map do |key, value|
      if key == 'changes' && value.is_a?(Hash)
        value.map { |field, change| describe_change(field, change) }
      else
        "#{key.to_s.humanize.downcase}: #{audit_value(value)}"
      end
    end.join('; ')
  end

  # The setting's label rather than its key, where there is one.
  def setting_label(key)
    SiteSetting::DEFINITIONS[key.to_s]&.label || key.to_s.humanize
  end

  # Checkbox / field value for the settings form: what was just submitted if the
  # form is being redisplayed with errors, otherwise what is saved.
  def setting_form_value(definition, submitted)
    submitted.key?(definition.key) ? submitted[definition.key] : SiteSetting.get(definition.key)
  end

  private

  def describe_change(field, change)
    label = SiteSetting::DEFINITIONS.key?(field) ? setting_label(field) : field.to_s.humanize.downcase
    return "#{label} changed" unless change.is_a?(Array)

    "#{label}: #{audit_value(change.first)} → #{audit_value(change.last)}"
  end

  def audit_value(value)
    text = value.is_a?(Hash) || value.is_a?(Array) ? value.to_json : value.to_s
    return '(empty)' if text.blank?

    truncate(text, length: 80)
  end
end
