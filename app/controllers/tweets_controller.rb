class TweetsController < ApplicationController
  before_action :authenticate_user!

  def index
    @tweets = Current.user.tweets
  end

  def new
    @tweet = Tweet.new
  end

end