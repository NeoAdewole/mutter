class SiteSetting
  # The list of settings an admin can change: name, type, default, limits and the
  # wording shown on the settings page. Add a setting here and it appears there.
  module Definitions
    Definition = Struct.new(:key, :type, :default, :label, :help, :group, :choices, :range, :max_length, keyword_init: true)

    ALL = [
      Definition.new(key: 'maintenance_mode', type: :boolean, default: false, group: 'Availability',
                     label: 'Maintenance mode',
                     help: 'Visitors see a maintenance page instead of the site. Admins can still sign in and use the site, ' \
                           'so you can switch this off again.'),
      Definition.new(key: 'maintenance_message', type: :string, default: '', group: 'Availability', max_length: 500,
                     label: 'Maintenance message',
                     help: 'Shown on the maintenance page. Leave blank for the standard message.'),
      Definition.new(key: 'signups_enabled', type: :boolean, default: true, group: 'Availability',
                     label: 'Allow new sign-ups',
                     help: 'Turn off to stop new accounts being created, by form or by a provider. Existing users can still sign in.'),
      Definition.new(key: 'announcement_enabled', type: :boolean, default: false, group: 'Announcement banner',
                     label: 'Show the banner',
                     help: 'Displayed at the top of every page for every visitor.'),
      Definition.new(key: 'announcement_message', type: :string, default: '', group: 'Announcement banner', max_length: 300,
                     label: 'Banner message', help: 'Plain text, up to 300 characters.'),
      Definition.new(key: 'announcement_level', type: :enum, default: 'info', group: 'Announcement banner',
                     choices: %w[info success warning error], label: 'Banner style',
                     help: 'Info is blue, success green, warning amber, error red.'),
      Definition.new(key: 'homepage_streams_enabled', type: :boolean, default: true, group: 'Home page',
                     label: 'Show live streams on the home page',
                     help: 'Live Twitch streams from members appear first in any carousel set to show them (the Home page carousel is by default). Members can still opt out individually.'),
      Definition.new(key: 'homepage_streams_limit', type: :integer, default: 5, group: 'Home page', range: 1..10,
                     label: 'Most streams to show',
                     help: 'The busiest streams (by current viewers) are shown first. Between 1 and 10.')
    ].index_by(&:key).freeze
  end
end
