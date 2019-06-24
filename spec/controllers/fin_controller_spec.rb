# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FinController, type: :controller do
  describe 'GET #index' do
    it 'returns http success' do
      get :index
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET #upload_result_file' do
    it 'returns http success' do
      get :upload_result_file
      expect(response).to have_http_status(:success)
    end
  end
end
