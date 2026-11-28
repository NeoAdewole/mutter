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
      @providers ||= AuthProviders.all.map { |provider| Provider.new(provider.label, provider.configured?) }
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

    def pending_migrations?
      ActiveRecord::Base.connection_pool.migration_context.needs_migration?
    end
  end
end
