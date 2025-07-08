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

    def create
      @editor = Editor.new(editor_params)

      # Auto-generate OAuth credentials
      @editor.client_id = SecureRandom.hex(16)
      @editor.client_secret = SecureRandom.hex(32)

      if @editor.save
        @editor.sync_to_doorkeeper!
        redirect_to admin_editor_path(@editor), notice: 'Éditeur créé avec succès.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @editor.update(editor_params)
        @editor.sync_to_doorkeeper!
        redirect_to admin_editor_path(@editor), notice: 'Éditeur mis à jour avec succès.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @editor.destroy!
      redirect_to admin_editors_path, notice: 'Éditeur supprimé avec succès.'
    end

    def sync_doorkeeper
      @editor.sync_to_doorkeeper!
      redirect_to admin_editor_path(@editor), notice: 'Application Doorkeeper synchronisée.'
    end

    private

    def set_editor
      @editor = Editor.find(params[:id])
    end

    def editor_params
      params.require(:editor).permit(:name, :callback_url, :authorized, :active)
    end
  end
end
