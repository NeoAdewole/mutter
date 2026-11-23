class AboutController < ApplicationController
  def index
    @page = SitePages.page('about')
  end
end
