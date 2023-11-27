class TweetsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_tweet, only: [:show, :edit, :update, :destroy]

  def index
    @tweets = Current.user.tweets
  end

  def new
    @tweet = Tweet.new
  end

  def create
    @tweet = Current.user.tweets.new(tweet_params)
    if @tweet.save
      redirect_to tweets_path, notice: "Tweet was scheduled successfully"
    else
      render :new, status: 442
    end
  end
  
  def show
  end

  def edit
  end

  def update
    if @tweet.update(tweet_params)
      redirect_to tweets_path, notice: "Tweet updated successfully"
    else
      render :edit
    end
  end

  def destroy
    if @tweet.destroy
      redirect_to tweets_path, notice: "Tweet was unscheduled"
    else
      redirect_to tweets_path, alert: "Unable to remove schedule, please try again."
    end
  end

  private

  def tweet_params
    params.require(:tweet).permit(:twitter_account_id, :body, :publish_at)
  end

  def set_tweet
    @tweet = Current.user.tweets.find(params[:id])
  end

end