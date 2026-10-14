# frozen_string_literal: true

# Shared table sorting: controllers whitelist their sort keys, unknown
# keys and directions fall back to the table default.
module Sortable
  extend ActiveSupport::Concern

  private

  def sort_key(allowed_keys)
    allowed_keys.include?(params[:sort]) ? params[:sort] : nil
  end

  def sort_direction
    params[:direction] == "desc" ? "desc" : "asc"
  end
end
