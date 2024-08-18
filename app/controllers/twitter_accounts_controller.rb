class TwitterAccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_twitter_account, only: [:destroy]

  def index
    @twitter_accounts = Current.user.twitter_accounts
  end

  def destroy
    @twitter_account = Current.user.twitter_accounts.find(params[:id]) 
    if @twitter_account.destroy
      redirect_to twitter_accounts_path, notice: "@#{@twitter_account.username} successfully disconnected"
    else
      redirect_to twitter_accounts_path, alert: "Something went wrong, please try again."
    end      
  end

  private

  def set_twitter_account
    @twitter_account = Current.user.twitter_accounts.find(params[:id])
  end

end