module Admin
  # The slides of a carousel and the cards of a row of cards. Audited against the
  # page they appear on.
  class BlockItemsController < BaseController
    before_action :set_item, only: %i[edit update destroy move]
    before_action :set_block, only: %i[new create]
    before_action :require_item_block, only: %i[new create]

    def new
      @item = @block.items.new
    end

    def create
      @item = @block.items.new(item_params)
      if @item.save
        record 'added', @item
        redirect_to edit_admin_block_path(@block), notice: "Added the #{@block.item_name}: #{@item.label}."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @item.update(item_params)
        record 'edited', @item
        redirect_to edit_admin_block_path(@item.block), notice: "Saved the #{@item.block.item_name}: #{@item.label}."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @item.destroy!
      record 'removed', @item
      redirect_to edit_admin_block_path(@item.block), notice: "Removed the #{@item.block.item_name}: #{@item.label}."
    end

    def move
      direction = params[:direction].to_s
      return head :bad_request unless %w[up down].include?(direction)

      @item.move(direction)
      audit 'page.block_moved', target: @item.block.page,
                                details: { block: @item.block.label, item: @item.label, direction: direction }
      redirect_to edit_admin_block_path(@item.block)
    end

    private

    def set_item
      @item = BlockItem.find(params[:id])
    end

    def set_block
      @block = PageBlock.find(params[:block_id])
    end

    # Text blocks have no slides or cards.
    def require_item_block
      render_not_found unless @block.holds_items?
    end

    def item_params
      block = @item&.block || @block
      params.require(:block_item).permit(*BlockItem.permitted_for(block.kind))
    end

    def record(what, item)
      block = item.block
      audit 'page.block_updated', target: block.page, details: { block: block.label, item: "#{what} #{block.item_name} “#{item.label}”" }
    end
  end
end
