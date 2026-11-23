class SectionsController < ApplicationController
  def show
    @section = Section.find(params[:section])
    return render_not_found unless @section

    @page = SitePages.page(@section.key)
    @nodes = Page.navigation.fetch(@section.key)
  end
end
