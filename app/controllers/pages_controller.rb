class PagesController < ApplicationController
  def show
    @section = Section.find(params[:section])
    @page = Page.find_by_path(params[:section], params[:path])
    return render_not_found unless @section && @page && (@page.publicly_visible? || admin_signed_in?)

    # Admins may look at drafts (and published pages beneath drafts) to preview them.
    @draft_preview = !@page.publicly_visible?
    @sub_pages = @page.children.select(&:published?)
  end
end
