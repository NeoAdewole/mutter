module Admin
  class UsersController < BaseController
    before_action :set_user, except: :index
    # Admins can't demote, suspend or delete themselves. Because only *other*
    # admins can do those to an admin, at least one admin always remains.
    before_action :refuse_self_action, only: %i[revoke_admin suspend destroy]

    ROLES = %w[admin regular].freeze
    STATUSES = %w[active suspended].freeze

    def index
      @filters = filter_params
      @users, @pagination = paginate(filtered_users.includes(:identities))
    end

    def show
      @identities = @user.identities.order(:created_at)
      @activity = AuditLog.involving(@user).newest_first.limit(10)
    end

    def edit; end

    def update
      @user.assign_attributes(profile_params)
      changes = @user.changes.except('updated_at')
      if @user.save
        audit 'user.updated', target: @user, details: { changes: changes } if changes.any?
        redirect_to admin_user_path(@user), notice: "Saved #{@user.username}."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def grant_admin
      return redirect_to(admin_user_path(@user), notice: "#{@user.username} is already an admin.") if @user.admin?

      @user.update!(admin: true)
      audit 'user.admin_granted', target: @user
      redirect_to admin_user_path(@user), notice: "#{@user.username} is now an admin."
    end

    def revoke_admin
      return redirect_to(admin_user_path(@user), notice: "#{@user.username} isn't an admin.") unless @user.admin?

      @user.update!(admin: false)
      audit 'user.admin_revoked', target: @user
      redirect_to admin_user_path(@user), notice: "#{@user.username} is no longer an admin."
    end

    def suspend
      return redirect_to(admin_user_path(@user), notice: "#{@user.username} is already suspended.") if @user.suspended?

      @user.suspend!(reason: params[:reason])
      audit 'user.suspended', target: @user, details: { reason: @user.suspension_reason }.compact
      redirect_to admin_user_path(@user), notice: "Suspended #{@user.username}. They are signed out and can't sign in."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_user_path(@user), alert: "Couldn't suspend: #{e.record.errors.full_messages.to_sentence}."
    end

    def unsuspend
      return redirect_to(admin_user_path(@user), notice: "#{@user.username} isn't suspended.") unless @user.suspended?

      @user.unsuspend!
      audit 'user.unsuspended', target: @user
      redirect_to admin_user_path(@user), notice: "#{@user.username} can sign in again."
    end

    def destroy
      @user.destroy!
      audit 'user.deleted', target: @user
      redirect_to admin_users_path, notice: "Deleted #{@user.username}, along with their linked accounts and tweets."
    end

    def send_password_reset
      return redirect_to(admin_user_path(@user), alert: "#{@user.username} has no real email address yet.") if @user.placeholder_email?

      PasswordMailer.with(user: @user).password_reset.deliver_now
      audit 'user.password_reset_sent', target: @user
      redirect_to admin_user_path(@user), notice: "Password reset email sent to #{@user.email}. The link works for 15 minutes."
    rescue StandardError => e
      Rails.logger.error("Admin password reset email failed: #{e.class}: #{e.message}")
      redirect_to admin_user_path(@user), alert: "The email couldn't be sent (#{e.class}). Check the mail settings."
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def refuse_self_action
      return unless @user == current_user

      redirect_to admin_user_path(@user), alert: "You can't do that to your own account here. Ask another admin."
    end

    def profile_params
      params.require(:user).permit(:firstname, :lastname, :username, :email)
    end

    # Only known values are honoured, so a made-up filter can't reach the query.
    def filter_params
      {
        q: params[:q].to_s.strip,
        role: params[:role].presence_in(ROLES),
        status: params[:status].presence_in(STATUSES),
        provider: params[:provider].presence_in(Identity::PROVIDER_LABELS.keys),
        sort: params[:sort].presence_in(User::SORTS.keys) || 'newest'
      }
    end

    def filtered_users
      f = @filters
      scope = User.search(f[:q]).sorted_by(f[:sort])
      scope = f[:role] == 'admin' ? scope.admins : scope.regular if f[:role]
      scope = f[:status] == 'suspended' ? scope.suspended : scope.active if f[:status]
      scope = scope.with_provider(f[:provider]) if f[:provider]
      scope
    end
  end
end
