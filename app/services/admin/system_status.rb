module Admin
  # A read-only health snapshot for the admin System page. It reports whether
  # each integration has credentials, never the credentials themselves.
  class SystemStatus
    Provider = Struct.new(:label, :configured)

    def app
      {
        'Environment' => Rails.env,
        'Rails' => Rails.version,
        'Ruby' => RUBY_VERSION,
        'Time zone' => Time.zone.name,
        'Cache store' => Rails.cache.class.name.demodulize,
        'Mail delivery' => ActionMailer::Base.delivery_method.to_s
      }
    end

    def database
      @database ||= begin
        connection = ActiveRecord::Base.connection
        {
          connected: connection.active?,
          adapter: connection.adapter_name,
          server_version: connection.select_value('SHOW server_version').to_s,
          pending_migrations: pending_migrations?
        }
      rescue ActiveRecord::ActiveRecordError => e
        { connected: false, error: e.class.name }
      end
    end

    def providers
      @providers ||= [
        provider('GitHub', credentials.dig(:github, :client_id), credentials.dig(:github, :client_secret)),
        provider('Google (sign-in and YouTube)', credentials.dig(:google, :client_id), credentials.dig(:google, :client_secret)),
        provider('Twitter', credentials.dig(:twitter, :client_id), credentials.dig(:twitter, :client_secret)),
        provider('Discord', credentials.dig(:discord, :client_id), credentials.dig(:discord, :client_secret)),
        twitch_provider
      ]
    end

    def record_counts
      {
        'Users' => User.count,
        'Linked accounts' => Identity.count,
        'Pages' => Page.in_sections.count,
        'Site pages' => Page.site_pages.count,
        'Audit log entries' => AuditLog.count
      }
    end

    private

    def credentials
      Rails.application.credentials
    end

    def provider(label, id, secret)
      Provider.new(label, id.present? && secret.present?)
    end

    # Twitch credentials are stored flat or nested; the same lookup the sign-in and live-stream code use.
    def twitch_provider
      id = credentials.dig(:twitch, :client_id) || credentials[:twitch_client_id]
      secret = credentials.dig(:twitch, :client_secret) || credentials[:twitch_client_secret]
      Provider.new('Twitch (sign-in and live streams)', id.present? && secret.present?)
    end

    def pending_migrations?
      ActiveRecord::Base.connection_pool.migration_context.needs_migration?
    end
  end
end
