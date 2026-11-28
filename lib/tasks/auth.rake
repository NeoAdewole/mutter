namespace :auth do
  desc 'Which sign-in providers are set up, and the callback address each must have registered: ' \
       'bin/rails auth:status  (BASE_URL=https://your-site.example for another host)'
  task status: :environment do
    base = ENV.fetch('BASE_URL', 'http://localhost:3000').chomp('/')

    AuthProviders.all.each do |provider|
      state = provider.configured? ? 'configured' : 'MISSING   '
      puts format('%-10<state>s %-10<name>s %<url>s', state: state, name: provider.label, url: "#{base}#{provider.callback_path}")
    end

    missing = AuthProviders.all.reject(&:configured?)
    puts "\nSet up #{missing.map(&:label).join(', ')}: see docs/AUTH_SETUP.md." if missing.any?
  end
end
