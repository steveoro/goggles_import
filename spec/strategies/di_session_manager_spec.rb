# frozen_string_literal: true

require 'rails_helper'
require 'di_session_manager'

describe DISessionManager, type: :strategy do
  let(:file_name)    { "#{FFaker::Filesystem.file_name}.json" }
  let(:source_data)  { { product: FFaker::Product.product } }
  let(:season_id)    { 0 }
  let(:user_id)      { [1, 2].sample }
  #-- -------------------------------------------------------------------------
  #++

  describe 'self.create!(' do
    context 'without some of the required and valid column values,' do
      it 'returns nil' do
      end
    end

    context 'with all the required and valid column values,' do
      it 'returns the new instance' do
      end
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'self.destroy!' do
    context 'for an invalid or nil di_session,' do
      it 'returns false' do
      end
    end

    context 'for a valid di_session,' do
      it 'returns true' do
      end
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
