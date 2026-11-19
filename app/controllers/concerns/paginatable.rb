# Offset pagination for the admin lists, without a gem. `paginate` returns the
# page of records and a Pagination the view uses for its "Previous / Next" links.
module Paginatable
  extend ActiveSupport::Concern

  DEFAULT_PER_PAGE = 25

  Pagination = Struct.new(:page, :per_page, :total) do
    def pages
      [(total.to_f / per_page).ceil, 1].max
    end

    def first_item
      total.zero? ? 0 : ((page - 1) * per_page) + 1
    end

    def last_item
      [page * per_page, total].min
    end

    def previous_page
      page - 1 if page > 1
    end

    def next_page
      page + 1 if page < pages
    end
  end

  private

  def paginate(scope, per_page: DEFAULT_PER_PAGE)
    total = scope.count
    pagination = Pagination.new(1, per_page, total)
    pagination.page = params[:page].to_i.clamp(1, pagination.pages)
    [scope.limit(per_page).offset((pagination.page - 1) * per_page), pagination]
  end
end
