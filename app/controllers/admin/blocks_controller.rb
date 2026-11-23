module Admin
  # Adds, edits, reorders and removes the blocks of a page. Everything is audited
  # against the page, since a block is part of it.
  class BlocksController < BaseController
    before_action :set_block, only: %i[edit update destroy move]

    # POST /admin/pages/:page_id/blocks?kind=cards - creates the block with its
    # defaults and opens it for filling in.
    def create
      page = Page.find(params[:page_id])
      block = page.blocks.new(kind: params[:kind].to_s)
      if block.save
        audit 'page.block_added', target: page, details: { block: block.label }
        redirect_to edit_admin_block_path(block), notice: "Added a #{block.label.downcase}. Fill it in below."
      else
        redirect_to edit_admin_page_path(page), alert: block.errors.full_messages.to_sentence
      end
    end

    def edit; end

    def update
      @block.assign_attributes(block_params)
      changed = @block.changes.except('updated_at').transform_values { |old, new| field_change(old, new) }
      if @block.save
        audit 'page.block_updated', target: @block.page, details: { block: @block.label, changes: changed }
        redirect_to edit_admin_block_path(@block), notice: "#{@block.label} saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @block.destroy!
      audit 'page.block_removed', target: @block.page, details: { block: @block.label }
      redirect_to edit_admin_page_path(@block.page), notice: "Removed the #{@block.label.downcase}."
    end

    def move
      direction = params[:direction].to_s
      return head :bad_request unless %w[up down].include?(direction)

      @block.move(direction)
      audit 'page.block_moved', target: @block.page, details: { block: @block.label, direction: direction }
      redirect_to edit_admin_page_path(@block.page)
    end

    private

    def set_block
      @block = PageBlock.find(params[:id])
    end

    def block_params
      params.require(:page_block).permit(*PageBlock.permitted_for(@block.kind))
    end

    def field_change(old, new)
      return 'changed' if old.to_s.length > 200 || new.to_s.length > 200

      [old, new]
    end
  end
end
