class SectionsController < ApplicationController
  def show
    @section = Section.find(params[:section])
    return render_not_found unless @section

    @nodes = Page.navigation.fetch(@section.key)
  end
end
