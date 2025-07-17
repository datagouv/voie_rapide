# frozen_string_literal: true

module Admin
  class EditorsController < ApplicationController
    before_action :set_editor, only: %i[show edit update destroy sync_doorkeeper]

    def index
      @editors = Editor.order(:name)
    end

    def show
      @doorkeeper_app = @editor.doorkeeper_application
    end

    def new
      @editor = Editor.new
    end

    def edit; end

    def create
      @editor = Editor.new(editor_params)

      # Auto-generate OAuth credentials
      @editor.client_id = SecureRandom.hex(16)
      @editor.client_secret = SecureRandom.hex(32)

      if @editor.save
        @editor.sync_to_doorkeeper!
        redirect_to admin_editor_path(@editor), notice: I18n.t('admin.editors.created')
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @editor.update(editor_params)
        @editor.sync_to_doorkeeper!
        redirect_to admin_editor_path(@editor), notice: I18n.t('admin.editors.updated')
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @editor.destroy!
      redirect_to admin_editors_path, notice: I18n.t('admin.editors.deleted')
    end

    def sync_doorkeeper
      @editor.sync_to_doorkeeper!
      redirect_to admin_editor_path(@editor), notice: I18n.t('admin.editors.doorkeeper_synced')
    end

    private

    def set_editor
      @editor = Editor.find(params[:id])
    end

    def editor_params
      params.expect(editor: %i[name callback_url authorized active])
    end
  end
end
