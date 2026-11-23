class MainController < ApplicationController
  # The Home page is a site page made of blocks. Live streams in its carousel are
  # governed by Admin > Settings (see PageBlocksHelper#carousel_streams).
  def index
    @page = SitePages.page('home')
  end
end
