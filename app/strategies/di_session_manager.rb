# frozen_string_literal: true

#
# = DISessionManager
#
#  - Goggles framework vers.:  6.400
#  - author: Steve A.
#
#  Allows to create or destroy a new DataImportSession row. When destroing the session,
#  it will take care of destroying the related entities too.
#
class DISessionManager

  # Creates a new data-import session in the database.
  # When successful, returns the new instance. Raises RecordInvalid on error.
  #
  # === Params:
  # - options : Hash of DataImportSession column values used to create the new row
  #
  def self.create!( options = {} )
    result = DataImportSession.new(
      phase: options[:phase] || 0,
      file_format: options[:file_format] || 'json',
      file_name: options[:file_name],
      source_data: options[:source_data] = '',
      total_data_rows: options[:total_data_rows] || 0,
      season_id: options[:season_id],
      phase_1_log: '', # List of DB-diffs produced
      phase_2_log: '', # Current meeting instance processed (with class name)
      phase_3_log: '', # Latest data-import status
      sql_diff: '', # Actual resulting, final Meeting.id (just the ID), after phase-3
      data_import_season_id: nil,
      user_id: options[:user_id] || 1
    )
    result.save!
  rescue StandardError
    # DEBUG
    puts ValidationErrorTools.recursive_error_for( result )
    raise ActiveRecord::RecordInvalid
  end
  #-- --------------------------------------------------------------------------
  #++

  # Destroys an existing DataImportSession together with all its associated entity rows.
  #
  # Returns +true+ if the DataImportSession was destroyed, +false+ otherwise.
  #
  # === Params:
  # - di_session : a valid DataImportSession instance
  #
  def self.destroy!( di_session )
    DataImportSession.transaction do
      DataImportMeetingIndividualResult.where( data_import_session_id: di_session.id ).delete_all
      DataImportMeetingEntry.where( data_import_session_id: di_session.id ).delete_all
      DataImportMeetingProgram.where( data_import_session_id: di_session.id ).delete_all
      DataImportMeetingRelayResult.where( data_import_session_id: di_session.id ).delete_all
      DataImportMeetingSession.where( data_import_session_id: di_session.id ).delete_all
      DataImportMeetingTeamScore.where( data_import_session_id: di_session.id ).delete_all
      DataImportMeeting.where( data_import_session_id: di_session.id ).delete_all
      DataImportSeason.where( data_import_session_id: di_session.id ).delete_all
      DataImportSwimmer.where( data_import_session_id: di_session.id ).delete_all
      DataImportTeam.where( data_import_session_id: di_session.id ).delete_all
      DataImportBadge.where( data_import_session_id: di_session.id ).delete_all
      DataImportCity.where( data_import_session_id: di_session.id ).delete_all
      DataImportTeamAnalysisResult.where( data_import_session_id: di_session.id ).delete_all
      DataImportSwimmerAnalysisResult.where( data_import_session_id: di_session.id ).delete_all
      di_session.destroy # returns false if not successful
    end
  end
  #-- --------------------------------------------------------------------------
  #++

end
