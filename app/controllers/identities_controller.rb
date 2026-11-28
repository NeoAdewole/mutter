# Lets a signed-in person disconnect one of their own connected accounts from the profile page.
class IdentitiesController < ApplicationController
  before_action :authenticate_user!

  def destroy
    identity = current_user.identities.find(params[:id])
    label = Identity.label_for(identity.provider)

    unless identity.connect_only? || current_user.can_sign_in_without?(identity)
      return redirect_to edit_registration_path,
                         alert: "#{label} is the only way you can sign in. Add a password or connect another account first, " \
                                'or you would be locked out.'
    end

    identity.destroy!
    redirect_to edit_registration_path, notice: "Disconnected your #{label} account."
  end
end
