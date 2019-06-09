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
      it 'raises a ValidationError (no valid season)' do
        expect { DISessionManager.create!(file_name: '', season_id: 0) }.to raise_error( ActiveRecord::RecordInvalid )
      end
    end

    context 'with all the required and valid column values,' do
      it 'returns the new instance' do
        count_before = DataImportSession.count
        result = DISessionManager.create!(file_name: '', season_id: Season.limit(100).pluck(:id).sample)
        expect( result ).to be_a( DataImportSession )
        expect( DataImportSession.count ).to eq( count_before + 1 )
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
