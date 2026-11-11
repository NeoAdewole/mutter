module Admin
  class PagesController < BaseController
    before_action :set_page, only: %i[edit update destroy publish unpublish move]

    def index
      @rows_by_section = Section.all.index_with { |section| Page.rows_for(section.key) }
    end

    def new
      @page = Page.new(section: requested_section)
    end

    def create
      @page = Page.new(create_params)
      if @page.save
        redirect_to admin_pages_path, notice: "Page created: #{@page.title}."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @page.update(update_params)
        redirect_to admin_pages_path, notice: "Page saved: #{@page.title}."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @page.destroy
        redirect_to admin_pages_path, notice: "Page deleted: #{@page.title}."
      else
        redirect_to admin_pages_path,
                    alert: "“#{@page.title}” still has sub pages. Move or delete its sub pages first."
      end
    end

    def publish
      @page.update!(published: true)
      redirect_to admin_pages_path, notice: "Published: #{@page.title}."
    end

    def unpublish
      @page.update!(published: false)
      redirect_to admin_pages_path, notice: "Unpublished: #{@page.title} (now a draft)."
    end

    def move
      direction = params[:direction].to_s
      return head :bad_request unless %w[up down].include?(direction)

      @page.move(direction)
      redirect_to admin_pages_path
    end

    private

    def set_page
      @page = Page.find(params[:id])
    end

    def requested_section
      Section.find(params[:section])&.key || Section.all.first.key
    end

    # The section is chosen once, when the page is created.
    def create_params
      params.require(:page).permit(:section, :title, :slug, :body, :parent_id, :published)
    end

    def update_params
      params.require(:page).permit(:title, :slug, :body, :parent_id, :published)
    end
  end
end
