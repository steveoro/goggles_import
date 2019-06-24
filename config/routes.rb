# frozen_string_literal: true

Rails.application.routes.draw do
  get 'fin/index'

  get 'fin/upload_result_file'

  get 'home/index'

  # The priority is based upon order of creation:
  # first created -> highest priority.
  mount GogglesCore::Engine => 'home/index'

  devise_for :admins
end
