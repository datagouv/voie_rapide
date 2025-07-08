# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @editors_count = Editor.count
    @markets_count = PublicMarket.count
    @applications_count = Application.count
    @documents_count = Document.active.count
  end
end
