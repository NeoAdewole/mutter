module Admin
  # The numbers on the admin dashboard. Everything is computed on demand (a
  # handful of cheap, indexed queries) so there is nothing to keep in sync.
  class DashboardStats
    SIGNUP_DAYS = 14

    UserCounts = Struct.new(:total, :admins, :suspended, :new_this_week, :new_this_month, :active_this_week, :missing_email)
    PageCounts = Struct.new(:section, :published, :drafts)

    def users
      @users ||= UserCounts.new(
        User.count,
        User.admins.count,
        User.suspended.count,
        User.where(created_at: 7.days.ago..).count,
        User.where(created_at: 30.days.ago..).count,
        User.where(last_sign_in_at: 7.days.ago..).count,
        User.where('email LIKE ?', "%@#{User::PLACEHOLDER_EMAIL_DOMAIN}").count
      )
    end

    # [[date, signups], ...] oldest first, one entry per day including quiet days.
    def signups_by_day
      @signups_by_day ||= begin
        first_day = (SIGNUP_DAYS - 1).days.ago.to_date
        counts = User.where(created_at: first_day.beginning_of_day..).group('date(users.created_at)').count
        (first_day..Time.zone.today).map { |day| [day, counts.fetch(day, 0)] }
      end
    end

    def busiest_signup_day
      [signups_by_day.map(&:last).max.to_i, 1].max
    end

    # [[label, count], ...] biggest first.
    def connections_by_provider
      @connections_by_provider ||= Identity.group(:provider).count
                                           .map { |provider, count| [Identity.label_for(provider), count] }
                                           .sort_by { |label, count| [-count, label] }
    end

    def pages
      @pages ||= begin
        counts = Page.group(:section, :published).count
        Section.all.map do |section|
          PageCounts.new(section, counts.fetch([section.key, true], 0), counts.fetch([section.key, false], 0))
        end
      end
    end

    def recent_users
      @recent_users ||= User.order(created_at: :desc, id: :desc).limit(5).to_a
    end

    def recent_activity
      @recent_activity ||= AuditLog.newest_first.limit(8).to_a
    end
  end
end
