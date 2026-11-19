module Admin
  # Removes one linked provider account from a user (for example one linked by
  # mistake, or a Twitch account that now belongs to someone else).
  class IdentitiesController < BaseController
    def destroy
      user = User.find(params[:user_id])
      identity = user.identities.find(params[:id])
      label = "#{Identity.label_for(identity.provider)}#{" (#{identity.username})" if identity.username.present?}"

      unless user.can_sign_in_without?(identity)
        return redirect_to admin_user_path(user),
                           alert: "#{user.username} has no password and #{label} is their only way to sign in. " \
                                  'Send them a password reset first, or they would be locked out.'
      end

      identity.destroy!
      audit 'user.identity_disconnected', target: user, details: { provider: identity.provider, handle: identity.username }.compact
      redirect_to admin_user_path(user), notice: "Disconnected #{label} from #{user.username}."
    end
  end
end
