# frozen_string_literal: true

class BaseController < ApplicationController
  include Sortable

  before_action :authenticate_user!
end
