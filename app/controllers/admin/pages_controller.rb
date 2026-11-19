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
        audit 'page.created', target: @page, details: { published: @page.published? }
        redirect_to admin_pages_path, notice: "Page created: #{@page.title}."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      @page.assign_attributes(update_params)
      changed = @page.changes.except('updated_at').transform_values { |old, new| field_change(old, new) }
      if @page.save
        audit 'page.updated', target: @page, details: { changes: changed }
        redirect_to admin_pages_path, notice: "Page saved: #{@page.title}."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @page.destroy
        audit 'page.deleted', target: @page
        redirect_to admin_pages_path, notice: "Page deleted: #{@page.title}."
      else
        redirect_to admin_pages_path,
                    alert: "“#{@page.title}” still has sub pages. Move or delete its sub pages first."
      end
    end

    def publish
      @page.update!(published: true)
      audit 'page.published', target: @page
      redirect_to admin_pages_path, notice: "Published: #{@page.title}."
    end

    def unpublish
      @page.update!(published: false)
      audit 'page.unpublished', target: @page
      redirect_to admin_pages_path, notice: "Unpublished: #{@page.title} (now a draft)."
    end

    def move
      direction = params[:direction].to_s
      return head :bad_request unless %w[up down].include?(direction)

      @page.move(direction)
      audit 'page.moved', target: @page, details: { direction: direction }
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

    # A page body can be long and is not worth copying into the log; record that it
    # changed, and the old/new value of everything short.
    def field_change(old, new)
      return 'changed' if old.to_s.length > 200 || new.to_s.length > 200

      [old, new]
    end
  end
end
