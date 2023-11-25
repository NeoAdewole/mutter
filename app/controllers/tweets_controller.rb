class TweetsController < ApplicationController
  before_action :authenticate_user!

  def index
    @tweets = Current.user.tweets
  end

  def new
    @tweet = Tweet.new
  end

  def create
    @tweet = Current.user.tweets.new(tweet_params)
    if @tweet.save
      redirect_to @tweet, notice: "Tweet was scheduled successfully"
    else
      render :new, status: 442
    end
  end

  private

  def tweet_params
    params.require(:tweet).permit(:twitter_account_id, :body, :publish_at)
  end

end