module Admin
  class AuditLogsController < BaseController
    PERIODS = { '1d' => 1.day, '7d' => 7.days, '30d' => 30.days }.freeze

    def index
      @filters = {
        action: params[:action_filter].presence_in(AuditLog::ACTIONS.keys),
        q: params[:q].to_s.strip,
        period: params[:period].presence_in(PERIODS.keys)
      }
      @entries, @pagination = paginate(filtered_entries, per_page: 50)
    end

    private

    def filtered_entries
      scope = AuditLog.newest_first
      scope = scope.for_action(@filters[:action]) if @filters[:action]
      scope = scope.where(created_at: PERIODS.fetch(@filters[:period]).ago..) if @filters[:period]
      scope = scope.where('actor_label ILIKE :p OR target_label ILIKE :p', p: "%#{AuditLog.sanitize_sql_like(@filters[:q])}%") if @filters[:q].present?
      scope
    end
  end
end
