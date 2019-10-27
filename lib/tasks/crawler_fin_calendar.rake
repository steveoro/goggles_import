# encoding: utf-8
require 'date'
require 'rubygems'
require 'fileutils'
# require 'mechanize'
require 'rest_client'

# require 'framework/console_logger'
#require 'meeting_name_normalizer'


=begin

= Web-Crawling Helper tasks

  - Goggles Framework vers.:  6.155
  - author: Steve A.

  (ASSUMES TO BE rakeD inside Rails.root)

=end


# (EXTERNAL_BASE_DIR is defined in core_00_constants.rake in 'goggles_core')
LOCALCOPY_DIR     = File.join( EXTERNAL_BASE_DIR, 'meeting_data', 'FIN_crawled')
LOG_DIR           = Rails.root.join('log') unless defined? LOG_DIR
#-- ---------------------------------------------------------------------------
#++


namespace :crawler do

  # Retrieves and memoizes the last FIN season id
  def get_current_fin_season_id
    # Memoize result to avoid multiple useless queries on the same run:
    @current_fin_season_id ||= Season.is_not_ended.includes(:season_type)
      .where('season_types.code': SeasonType::CODE_MAS_FIN).limit(1)
      .first
      .id
  end
  #-- -------------------------------------------------------------------------
  #++


  desc <<-DESC
  *** FIN Calendar STEP 1: "Calendar refresh" ***

Crawls the web to retrieve/update the current FIN Championship CALENDAR setup
for the current season.

All DB modifications are serialized on an external SQL DB-diff log file.

Options: [season_id=Season_id|<#{get_current_fin_season_id}>] [user_id=<1>]
         [output_path=#{LOCALCOPY_DIR}]

  - 'season_id' override for Season ID used to update the FIN calendar.
  - 'user_id' Admin user performing this action (defaults to 1).
  - 'output_path' the path where the files will be stored after the crawling.

DESC
  task( fin_calendar_step1: ['require_env'] ) do |t|
    puts "\r\n*** crawler::fin_calendar_step1 ***"
    output_path = ENV.include?("output_path") ? ENV["output_path"] : LOCALCOPY_DIR
    log_dir     = ENV.include?("log_dir") ? ENV["log_dir"] : LOG_DIR
    user_id     = ENV.include?("user_id") ? ENV["user_id"].to_i : 1
    season_id   = ENV.include?("season_id") ? ENV["season_id"].to_i : get_current_fin_season_id
    user        = User.find( user_id )

    unless Season.find_by(id: season_id )&.season_type&.code == SeasonType::CODE_MAS_FIN
      puts "Error: invalid season ID specifed (#{season_id}). Aborting..."
      exit
    end

    puts "\r\n\r\nProcessing FIN Calendar, season #{ season_id }..."
    puts "- output_path.......: #{ output_path }"
    puts "- log_dir...........: #{ log_dir }"
    puts "\r\n"

    calendar_rows_hash = from_csv_meeting_list_to_calendar_rows( meeting_list_on_csv_text )
    calendar_updater = FinCalendarPhase1Updater.new( user )
    calendar_updater.create_sql_diff_header()

    # Display the calendar data:
    puts "\r\n\r\n--- Tot. #{ calendar_rows_hash.values.count } ---"
    # Abort if there are no calendar rows:
    exit if calendar_rows_hash.values.count < 1

    # === UPDATE loop ===
    calendar_rows_hash.each do |coded_key, fin_calendar_row|
      # Process the row (either update or edit it):
      calendar_updater.process_row!( fin_calendar_row )
      putc "."
    end
    puts ""
    # Make an end summary:
    calendar_updater.report

    # Serialize SQL DB-diff:
    full_diff_pathname = compose_db_diff_filename( output_path, "prod_fin_calendar_p1_#{ calendar_rows_hash.values.first.season_id }", "1_update" )
    calendar_updater.save_diff_file( full_diff_pathname )
    puts "DB-diff file '#{ full_diff_pathname }' created."

    # === CLEAN-UP DB calendar === from outdated rows by comparing new, freshly retrieved version w/ version currently living on the DB:
    calendar_cleaner = FinCalendarPhase1Cleaner.new( user )
    calendar_cleaner.create_sql_diff_header()
    existing_calendar = FinCalendar.where( season_id: calendar_rows_hash.values.first.season_id ).to_a
    calendar_cleaner.process!( calendar_rows_hash.values, existing_calendar )
    calendar_cleaner.report

    # Serialize SQL DB-diff:
    full_diff_pathname = compose_db_diff_filename( output_path, "prod_fin_calendar_p1_#{ calendar_rows_hash.values.first.season_id }", "2_cleanup" )
    calendar_cleaner.save_diff_file( full_diff_pathname )
    puts "\r\nDB-diff file '#{ full_diff_pathname }' created.\r\nDone."
  end
  #-- -------------------------------------------------------------------------
  #++


  # Runs through a CSV list of allegedly updated meetings, obtained from running
  # the dedicated JS crawler 'fin-crawler.js', and returns
  #
  # === CSV format for parsing:
  #
  # startURL,date,isCancelled,name,place,meetingUrl,year
  #
  # === Returns
  #
  # An Hash of FinCalendar rows, one for each element of the result.
  #
  def from_csv_meeting_list_to_calendar_rows( meeting_list_on_csv_text )
    output_path = create_base_output_path_if_missing()
    # Start the crawler and wait for the results to be ready:
    api_results_endpoint = start_apifier_crawler( api_run_endpoint )
    # Retrieve the results:
    json_result = get_results_from_apifier_crawler( api_results_endpoint )

    # Build up the result list:
    # Hash of *unique* calendar rows: key = coded_suffix, value = calendar row
    calendar_rows = {}
# DEBUG
#    puts "json_result => #{ json_result.class }"
#    puts "json_result.first => #{ json_result.first.class }\r\n"

    # ASSERT: pageFunctionResult is an array of Hash:
    result_list = json_result.each do |parsed_hash|
      label = parsed_hash['label']
      current_url = parsed_hash['url']
      puts "\r\n\r\nProcessing results for season #{ label }"
      puts "(#{ current_url }) => #{ parsed_hash['pageFunctionResult'].size } tot. links"
      puts " "
                                                    # Create the output sub-path, if missing:
      full_output_path = File.join(output_path, label)
      FileUtils.mkdir_p( full_output_path ) if !File.directory?( full_output_path )

      # For each calendar URL, we have several row result Hash instances:
      parsed_hash['pageFunctionResult'].each_with_index do |row_hash, index|
        year  = row_hash['year']  # Year MUST always come from the calendar, not from parsing the Link
        month = row_hash['month']
        days  = row_hash['days']
        city  = row_hash['city']
        description = row_hash['description']
        # Compose the full URL for the extracted sub,links:
        link = "https://www.federnuoto.it#{ row_hash['link'] }"
        # Use a coded key for the Hash list:
        coded_date_key = FinCalendar.calendar_unique_key( year, month, days, city )
        puts "Processing #{ index + 1 }/#{ parsed_hash['pageFunctionResult'].size } => #{ coded_date_key }..."

        calendar_row = if calendar_rows.has_key?( coded_date_key )
          calendar_rows[ coded_date_key ]
        else
          FinCalendar.new(
            season_id: label.to_i,
            calendar_year: year,
            calendar_month: month,
            calendar_date: days,
            calendar_place: city
          )
        end

        # Overwrite nil fields with new values in case they are missing:
        calendar_row.season_id      ||= label.to_i
        calendar_row.calendar_year  ||= year
        calendar_row.calendar_month ||= month
        calendar_row.calendar_date  ||= days
        calendar_row.calendar_place ||= city
        calendar_row.goggles_meeting_code ||= NameNormalizer.get_meeting_code( description, city )

        if description =~ /risultati/i              # - MEETING RESULTS -
          calendar_row.results_link   = row_hash['link']
          # - EXTRACT FIN CODE from link:
          uri = URI( row_hash['link'] )
          params_array = URI.decode_www_form( uri.query )
          fin_code = params_array.select{ |e| e.member?('codice') }.flatten.last
          calendar_row.fin_results_code ||= fin_code

        elsif description =~ /start/i               # - MEETING START-LIST -
          calendar_row.startlist_link = row_hash['link']
          # - EXTRACT FIN CODE from link:
          uri = URI( row_hash['link'] )
          params_array = URI.decode_www_form( uri.query )
          fin_code = params_array.select{ |e| e.member?('codice') }.flatten.last
          calendar_row.fin_startlist_code ||= fin_code

        else                                        # - MEETING MANIFEST -
          calendar_row.manifest_link  = row_hash['link']
          calendar_row.calendar_name  = description
          calendar_row.goggles_meeting_code ||= NameNormalizer.get_meeting_code( description, city )
        end
        # (Re-)Set the updated row into the parsed hash:
        calendar_rows[ coded_date_key ] = calendar_row
      end
    end

    puts "Scanning done."
    calendar_rows
  end
  #-- --------------------------------------------------------------------------
  #++



  desc <<-DESC
  *** FIN Calendar STEP 2: "Data extraction" ***

  Retrieves all Manifest and Result data files found at the URL links stored in
the dedicated DB columns of the fin_calendars setup data table (for the current
season only).

The calendar setup serialized on DB is assumed to have been already updated by
the "step 1" task.

Any old, previously existing files will be overwritten in the destination output
directory.

While scanning the stored calendar rows in order to read the URL links for file
retrieval and local serialization, the loop will update the dedicated text-type
columns of the calendar rows with the actual contents from the manifest files,
needed by the parsing phase of the "step 3" task.

All DB modifications are serialized on an external SQL DB-diff log file.

          *** This task uses the API @ apifier.com ***

Options: [ [season_id=Season_id|<#{get_current_fin_season_id}>] | [row_id=FIN_Calendar_row_id] ]
         [user_id=<1>]
         [use_files=<false>|true]
         [output_path=#{LOCALCOPY_DIR}]

  - 'season_id':      the ID of the FIN season to be crawled.
    (Currently supported seasons: 122, 132, 142, ... And so on, up to ID 182)

  - 'row_id':         the specific row ID of the *single* FIN calendar row
                      to be processed. Overrides and takes precedence over the
                      season_id parameter. (Useful to debug specific cases.)

  - 'user_id':        the default user_id for the admin performing this action
                      (defaults to 1).

  - 'use_files':      set this to 'true' (or '1' - default is false) to skip the
                      remote download and local overwrite of the files linked by
                      the current calendar row.
                      This will assume that the files are already existing under
                      the 'output_path' and are considered to be ok.
                      This flag is mainly useful for the re-processing of calendar
                      rows for program extraction.

  - 'output_path':    the path where the files will be stored after the crawling.

DESC
  task( fin_calendar_step2: ['require_env'] ) do |t|
    puts "\r\n*** crawler::fin_calendar_step2 ***"
    output_path = ENV.include?("output_path") ? ENV["output_path"] : LOCALCOPY_DIR
    log_dir     = ENV.include?("log_dir") ? ENV["log_dir"] : LOG_DIR
    user_id     = ENV.include?("user_id") ? ENV["user_id"].to_i : 1
    user        = User.find( user_id )
    use_files   = !!!( ENV["use_files"].to_s =~ /true|1/ui ).nil? # (default is false, so nil works in this case)
    season_id   = ENV.include?("season_id") ? ENV["season_id"].to_i : get_current_fin_season_id
    row_id      = ENV.include?("row_id")    ? ENV["row_id"].to_i : nil
    current_season = Season.find_by_id( season_id )
    if current_season.nil?
      puts "Error: invalid season ID specifed (#{season_id}). Aborting..."
      exit
    end
                                                    # Check existance of dest. directory (create the output sub-path, if missing):
    full_output_path = File.join( output_path, current_season.id.to_s )
    FileUtils.mkdir_p( full_output_path ) if !File.directory?( full_output_path )
    base_link = "https://www.federnuoto.it"

    # Read local calendar setup and collect all rows:
    existing_calendar = if row_id.nil?
      puts "\r\n\r\nProcessing FIN Calendar, season #{ current_season.id }..."
      FinCalendar.where( season_id: current_season.id )
    else
      puts "\r\n\r\nProcessing the SINGLE FIN Calendar row ID #{ row_id }..."
      FinCalendar.where( id: row_id )
    end
    puts "- use_files.............: #{ use_files ? 'ON' : '--' }"
    puts "- output_path...........: #{ output_path }"
    puts "- log_dir...............: #{ log_dir }"
    puts "\r\n"
    calendar_updater = FinCalendarPhase2Updater.new( user )

    # Scan calendar setup:
    existing_calendar.each do |fin_calendar_row|
      iso_date = FinCalendarMeetingBuilder.get_iso_date(
        fin_calendar_row.calendar_year,
        fin_calendar_row.calendar_month,
        fin_calendar_row.calendar_date,
        :first, "%04d%02d%02d"
      )
      puts "- Processing [ %40s | %01s | %01s | %01s ] %s" % [
        fin_calendar_row.goggles_meeting_code,
        (fin_calendar_row.results_link ? 'R' : ''),
        (fin_calendar_row.startlist_link ? 'S' : ''),
        (fin_calendar_row.manifest_link ? 'M' : ''),
        (iso_date.nil? ? ' => Dates undefined, skipping Phase-2.' : '')
      ]

      if iso_date
        base_filename = "#{ iso_date }#{ fin_calendar_row.goggles_meeting_code }"
                                                    # === RESULTS DATA download ===
        if fin_calendar_row.results_link && (!use_files)
          url_link = "#{ base_link }#{ fin_calendar_row.results_link }"
          calendar_dates = "#{ fin_calendar_row.calendar_date } #{ fin_calendar_row.calendar_month } #{ fin_calendar_row.calendar_year }"
          store_web_results(
            url_link,
            File.join(full_output_path, "ris#{ base_filename }.txt"),
            calendar_dates,
            true # use RestClient
          )
        end
                                                    # === STARTING-LIST DATA download ===
        if fin_calendar_row.startlist_link && (!use_files)
          url_link = "#{ base_link }#{ fin_calendar_row.startlist_link }"
          calendar_dates = "#{ fin_calendar_row.calendar_date } #{ fin_calendar_row.calendar_month } #{ fin_calendar_row.calendar_year }"
          store_web_results(
            url_link,
            File.join(full_output_path, "sta#{ base_filename }.txt"),
            calendar_dates,
            true # use RestClient
          )
        end
                                                    # === MANIFEST DATA download + "data extraction" ===
        if fin_calendar_row.manifest_link
          url_link = "#{ base_link }#{ fin_calendar_row.manifest_link }"
          relevant_data_hash = store_web_manifest(
            url_link,
            File.join(full_output_path, "man#{ base_filename }.html"),
            true, # use RestClient
            use_files
          )
          # Store relevant_data_hash into current row:
          fin_calendar_row.dates_import_text = relevant_data_hash[ :meeting_dates ]
          fin_calendar_row.name_import_text  = relevant_data_hash[ :entry_date_limit ]
          fin_calendar_row.organization_import_text = relevant_data_hash[ :organization ]
          fin_calendar_row.program_import_text = relevant_data_hash[ :program ]
          # Update the row and log the changes:
          calendar_updater.process_row!( fin_calendar_row )
        end
      end
    end

    # Make an end summary:
    calendar_updater.report

    # Serialize SQL DB-diff:
    full_diff_pathname = compose_db_diff_filename(
      output_path,
      "prod_fin_calendar_p2_#{ current_season.id }" + ( row_id ? "_#{ row_id }" : '' ),
      "update"
    )
    calendar_updater.save_diff_file( full_diff_pathname )
    puts "\r\nDB-diff file '#{ full_diff_pathname }' created.\r\nDone."
  end
  #-- -------------------------------------------------------------------------
  #++



  desc <<-DESC
  *** FIN Calendar Synch STEP 3: "Parse & Meeting update" ***

Scans and parses the dedicated DB text-type columns of the fin_calendars setup
data table (for the current season only) in order to extract the current meeting
session dates and meeting programs as they are defined in the manifest text of
each meeting.

The calendar setup serialized on DB is assumed to have been already updated by
the "step 1" & "step 2" task.
(The data found on the DB rows is assumed to be the latest available.)

All DB modifications are serialized on an external SQL DB-diff log file.


Options: [ [season_id=Season_id|<#{get_current_fin_season_id}>] | [row_id=FIN_Calendar_row_id] ]
         [user_id=<1>]
         [geocode=<false>|true]
         [api_key=Geocode_Google_Maps_API_Key]
         [skip_acquired=false|<true>] [disable=false|<true>]
         [output_path=#{LOCALCOPY_DIR}]
         [honor_single_update=false|<true>]

  - 'season_id':      the ID of the FIN season to be crawled.
    (Currently supported seasons: 122, 132, 142, ... And so on, up to ID 182)

  - 'row_id':         the specific row ID of the *single* FIN calendar row
                      to be processed. Overrides and takes precedence over the
                      season_id parameter. (Useful to debug specific cases.)

  - 'user_id':        the default user_id for the admin performing this action
                      (defaults to 1).

  - 'geocode':        set this to 'true' (or '1') to force the Geo-coding of each City.

  - 'api_key':        the GoogleMaps Geocode API key

  - 'skip_acquired':  set this to 'false' to force the update of every meeting found.

  - 'disable':        set this to 'false' to DESTROY a meeting instead of disabling it
                      during the clean-up phase at the end.
                      Meetings flagged as "disabled" won't be deleted at the next
                      clean-up phase, even if the 'disable' option as been set OFF.

  - 'output_path':    the path where the files will be stored after the crawling.

  - 'honor_single_update':  when 'true' (default) every Pool or City gets updated
                      at most a single time every run or every 30 minutes, depending
                      on which occurs first.

                      This is useful to ignore apparent subsequent changes found
                      when looping amongst all the rows of a calendar. Since
                      all values take origin from hand-written data, for instance,
                      a pool address may be found written in several different ways
                      even though all referring to the same address.

                      With the default on, an update to a Pool or City row found
                      having different values will be allowed only if the row itself
                      will be found +updated_on+ more than 30 minutes ago. (This is
                      the default timeout for the "single-update" feature.)

DESC
  task( fin_calendar_step3: ['require_env'] ) do |t|
    puts "\r\n*** crawler::fin_calendar_step3 ***"
    output_path = ENV.include?("output_path") ? ENV["output_path"] : LOCALCOPY_DIR
    log_dir     = ENV.include?("log_dir") ? ENV["log_dir"] : LOG_DIR
    user_id     = ENV.include?("user_id") ? ENV["user_id"].to_i : 1
    user        = User.find( user_id )
    season_id   = ENV.include?("season_id") ? ENV["season_id"].to_i : get_current_fin_season_id
    row_id      = ENV.include?("row_id")    ? ENV["row_id"].to_i : nil
    use_disable = ENV.include?("disable")   ? !!!( ENV["disable"].to_s =~ /true|1/ui ).nil? : true
    skip_acquired   = ENV.include?("skip_acquired") ? !!!( ENV["skip_acquired"].to_s =~ /true|1/ui ).nil? : true
    force_geocoding = !!!( ENV["geocode"].to_s =~ /true|1/ui ).nil? # (default is false, so nil works in this case)
    api_key     = ENV.include?("api_key") ? ENV["api_key"] : nil
    honor_single_update = ENV.include?("honor_single_update")   ? !!!( ENV["honor_single_update"].to_s =~ /true|1/ui ).nil? : true
    current_season  = Season.find_by_id( season_id )
    if current_season.nil?
      puts "Error: invalid season ID specifed (#{season_id}). Aborting..."
      exit
    end

    # Read local calendar setup and collect all rows:
    existing_calendar = if row_id.nil?
      puts "\r\n\r\nProcessing FIN Calendar, season #{ current_season.id }..."
      FinCalendar.where( season_id: current_season.id )
    else
      puts "\r\n\r\nProcessing the SINGLE FIN Calendar row ID #{ row_id }..."
      FinCalendar.where( id: row_id )
    end
    puts "- output_path...........: #{ output_path }"
    puts "- log_dir...............: #{ log_dir }"
    puts "- use_disable...........: #{ use_disable ? 'ON' : '--' }"
    puts "- skip_acquired.........: #{ skip_acquired ? 'ON' : '--' }"
    puts "- force_geocoding.......: #{ force_geocoding ? 'ON' : '--' }"
    puts "- api_key...............: '#{ api_key }'" if api_key.present?
    puts "- honor_single_update...: #{ honor_single_update ? 'ON' : '--' }"
    puts "\r\n"
    # Instantiate a single updater that will process each single row with the
    # result session DAOs list from the text parser:
    calendar_updater = FinCalendarPhase3Updater.new( user, honor_single_update, api_key )
    base_name = "prod_fin_calendar_p3_#{ current_season.id }"
    full_action_log_pathname = File.join( output_path, "#{ Time.zone.now.strftime('%Y%m%d%H%M') }#{ base_name }.log" )

    # Scan the calendar setup, row by row:
    existing_calendar.each do |fin_calendar_row|
      puts "Processing FIN calendar row ID #{ fin_calendar_row.id }..."
      # Parse the meeting program for the current row:
      parser = FinCalendarTextParser.new( fin_calendar_row )
      parser.parse!()
      # Process the resulting session(s):
      calendar_updater.process_row!(
        fin_calendar_row,
        parser.session_daos,
        force_geocoding,
        skip_acquired
      )

      # - SAVE ACTION LOG -  Append also the actions taken to the overall action log:
      File.open( full_action_log_pathname, 'a+' ) { |f| f.puts calendar_updater.action_log }
      puts "Action log updated."
      # - SAVE DB-DIFF -     Serialize an individual SQL DB-diff for each calendar row:
      if calendar_updater.has_changes?
        full_diff_pathname = compose_db_diff_filename( output_path, base_name, fin_calendar_row.id )
        calendar_updater.save_diff_file( full_diff_pathname )
        puts "DB-diff file '#{ full_diff_pathname }' created."
      end
    end

    # - SUMMARY REPORT - Make a brief, end summary in to the console and add it to the action log too:
    calendar_updater.report
    File.open( full_action_log_pathname, 'a+' ) { |f| calendar_updater.report( f ) }

    # Final phase:
    # 1. Clean-out empty sessions
    # 2. DESTROY (or disable) Meetings no more existing in the local calendar
    #    (unless they have been flagged as "cancelled", which means "keep it, even
    #    though there'll never be results acquired")
    meeting_cleaner = FinCalendarPhase3Cleaner.new( user )
    # Check & clean-out any empty sessions leftovers:
    meeting_cleaner.remove_empty_sessions!( season_id )
    # Process all "deletable" meetings:
    meeting_cleaner.process!(
      meeting_cleaner.collect_deletable_meetings( season_id ),
      use_disable
    )

    # - SUMMARY REPORT -
    meeting_cleaner.report
    # - SAVE ACTION LOG - Make an end summary for the cleaner and add it to the action log too:
    File.open( full_action_log_pathname, 'a+' ) { |f| meeting_cleaner.report( f ) }
    puts "\r\nAction log updated."

    # - SAVE DB-DIFF - Serialize SQL DB-diff for the Cleaner:
    if meeting_cleaner.has_changes?
      full_diff_pathname = compose_db_diff_filename( output_path, "prod_fin_calendar_p3_#{ season_id }", "cleanup" )
      meeting_cleaner.save_diff_file( full_diff_pathname )
      puts "DB-diff file '#{ full_diff_pathname }' created.\r\nDone."
    end

    puts "\r\nPhase-3 **finished**."
  end
  #-- -------------------------------------------------------------------------
  #++


  private


  # require 'net/http'
  # require 'uri'

  # Returns the web response for a specified page link using RestClient.
  # Note that this method may halt the program in case of errors.
  #
  # @param page_link, link to the page to be retrieved
  #
  def get_web_response( page_link, verbose = false )
    puts "  Retrieving '#{page_link}'..." if verbose
    must_retry = true
    while must_retry
      web_response = RestClient::Request.execute( url: page_link, method: :get, verify_ssl: false) do |response, request, result, &block|
        case response.code
        when 200..207
          must_retry = false
          response
        when 404
          puts " The request returned object not found! (Invalid link; error code: 404)"
          must_retry = false
          nil
        when 503
          puts " The request got frozen! (I will try again later; error code: 503)"
          nil
        when 504
          puts " Gateway timeout, error code: 504. I will try again later."
          nil
        else
          must_retry = false
          response.return!(&block) # Do the defaul behaviour in case of other codes
        end
      end
      if must_retry
        puts " Pausing 2 seconds before re-trying..."
        sleep(2)
      end
    end
    exit if web_response.nil?                     # Bail out in case of errors
    web_response
  end


  # Retrieves the specified page_link.
  #
  # @param page_link, link to the manifest page
  # @param use_restclient, +true+ to use RestClient gem; +false+ to use the standard Net::HTTP library
  #
  def get_html_doc_for_storage( page_link, use_restclient = true )
      puts "  Retrieving '#{page_link}' using #{ use_restclient ? 'RestClient' : 'Net::HTTP'} library..."
      web_response = use_restclient ? get_web_response( page_link ) : get_raw_web_response( page_link )
      puts "  #{ web_response.size } chars."
# DEBUG
#      puts "\r\n-----8<------"
#      puts web_response.to_s
#      puts "-----8<------"
#      puts " "
      Nokogiri::HTML( web_response ).css('#content')
  end


  # Retrieves and stores the specified page_link to the destination output_filename.
  #
  # === Params:
  # @param page_link, link to the manifest page
  # @param output_filename, the full output file name, minus the extension
  # @param use_restclient, +true+ to use RestClient gem; +false+ to use the standard Net::HTTP library
  #        [Steve, 20151122] Currently the Net::HTTP has issues while retrieving the single result or manifest pages
  # @param use_filesk, set this to true to skip remote download & local overwrite of the manifest files (default is false).
  #                    when true the local file will be loaded and parsed for program extraction.
  #
  # === Returns
  # An Hash of relevant data/text fields that to be then serialized into the fin_calendars
  # table.
  #
  # The hash fields are:  :meeting_dates, :entry_date_limit (not yet currently used),
  # :organization and :program.
  #
  def store_web_manifest( page_link, output_filename, use_restclient = true, use_files = false )
    relevant_data = {}
    if page_link.instance_of?(String) && page_link.size > 1
      html_doc = if use_files
        puts "  Reading directly existing manifest file..."
        file_text = File.open( output_filename ).read
        Nokogiri::HTML( file_text ).css('#content')
      else
        get_html_doc_for_storage( page_link, use_restclient )
      end
      html_doc.css('.stampa-loca').unlink           # Remove non-working external href to PDF print preview
                                                    # Retrieve all relevant data for the future parsing:
      relevant_data[:meeting_dates] = html_doc.css("p.data").text           # OR: html_doc.xpath("//p[@class='data']").text
      relevant_data[:entry_date_limit] = html_doc.css("p.iscrizioni").text  # OR: html_doc.xpath("//p[@class='iscrizioni']").text
      relevant_data[:organization] = html_doc.css("p.organizzazione").text  # OR: html_doc.xpath("//p[@class='organizzazione']").text
      # SEE http://www.rubydoc.info/github/sparklemotion/nokogiri/Nokogiri/XML/Searchable#xpath-instance_method
      # for XPath selector methods
      relevant_data[:program] = FinCalendarPhase2ProgramExtractor.extract_from_nokogiri_nodeset(
        html_doc,
        "\\bimpiant.\\b|\\borganizzazione\\b",
        "(\\binfo(rmazioni)?|accredito|logistic.)(?!\\@)"
      )
                                                    # Save to file with a minimal header: (only when not re-using existing files)
      unless use_files
        File.open( output_filename, 'w' ) do |f|
          f.puts "<!DOCTYPE html>"
          f.puts "<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"it-it\" lang=\"it-it\" dir=\"ltr\" >"
          f.puts "<head>"
          f.puts "  <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">"
          f.puts "</head>"
          f.puts "<body>"
          f.puts html_doc.to_html
          f.puts "</body>"
          f.puts "</html>"
        end
      end
    else
      puts "  Manifest link seems to be still undefined. 'Skipping."
    end
    relevant_data
  end


  # Retrieves and stores the specified page_link to the destination output_filename.
  #
  # === Params:
  #
  # @param page_link, link to the results or start-list page
  #
  # @param output_filename, the base for the output file name; a standardized suffix will be appended,
  #        based upon the file contents (the meeting title) and/or the actual city name
  #
  # @param meeting_dates, the actual "verbose date" (or dates) during which the meeting is held
  #
  # @param use_restclient, +true+ to use RestClient gem; +false+ to use the standard Net::HTTP library
  #        [Steve, 20151122] Currently the Net::HTTP has issues while retrieving the single result or manifest pages
  #
  def store_web_results( page_link, output_filename, meeting_dates, use_restclient = true )
    if page_link.instance_of?(String) && page_link.size > 1
      html_doc    = get_html_doc_for_storage( page_link, use_restclient )
      title       = html_doc.css( 'h1' ).text
      description = html_doc.css( 'h3' ).text
      event_list  = html_doc.css( '.gara h2' ).map { |node| node.text }
      result_list = html_doc.css( '.gara pre' ).map { |node| node.text }
                                                    # Extract the contents on file:
      File.open( output_filename, 'w' ) do |f|
        f.puts title
        f.puts description
        f.puts meeting_dates
        f.puts "\r\n#{ event_list.join(', ') }"
        f.puts "\r\n"
                                                    # Rebuild result list w/ titles:
        result_list.each_with_index do |result_text, index|
          f.puts "#{ event_list[ index ] }"
          f.puts "\r\n"
          f.puts result_text
          f.puts "\r\n"
        end
        if html_doc.css( '.classifica pre' ).size > 0
          f.puts "\r\nClassifica"
          f.puts "\r\n"
          f.puts html_doc.css( '.classifica pre' ).text
        end
        if html_doc.css( '.statistiche pre' ).size > 0
          f.puts "\r\nStatistiche"
          f.puts "\r\n"
          f.puts html_doc.css( '.statistiche pre' ).text
        end
      end
    else
      puts "  Results or Start-List link seems to be still undefined. 'Skipping."
    end
  end
  #-- -------------------------------------------------------------------------
  #++


  # Returns the selected/specified base output path for the crawled results output.
  #
  def create_base_output_path_if_missing()
    output_path = ENV.include?("output_path") ? ENV["output_path"] : LOCALCOPY_DIR
    puts "output_path:  #{output_path}"
                                                    # Create the base output path, if missing:
    FileUtils.mkdir_p( output_path ) if !File.directory?( output_path )
    output_path
  end
  #-- -------------------------------------------------------------------------
  #++


  # Starts the Apifier crawler at the specified endpoint, polling for a "finished" status.
  # If the returned status is != from 'SUCCEEDED', the program exits.
  #
  # On success, the method returns the API GET-results endpoint string.
  # @deprecated
  def start_apifier_crawler( api_run_endpoint )
    puts "\r\n"
    puts "Launching crawler..."                     # Call API to execute the crawler:
    web_response = post_raw_web_request( api_run_endpoint, true )
# DEBUG
#    puts "\r\n-------------------------[Full web response]----------------------"
#    puts web_response.body
#    puts "------------------------------------------------------------------\r\n"
    json_result = JSON.parse( web_response.body )
    status      = json_result['status']
    status_msg  = nil
    # Possible status codes:
    # RUNNING, SUCCEEDED, STOPPED, TIMEOUT or FAILED
    api_status_endpoint  = json_result['detailsUrl']
    api_results_endpoint = json_result['resultsUrl']

    while status == 'RUNNING'
      putc "."
      sleep(2)                                      # Wait a little for the API crawler to end
      putc "."
      web_response = get_raw_web_response( api_status_endpoint )
      json_result = JSON.parse( web_response.body ) # Check current crawler status
      status     = json_result['status']
      status_msg = json_result['statusMessage']
    end
    puts "\r\n"

    if status != 'SUCCEEDED'
      puts "Crawler API failed with result status '#{status}': #{status_msg}."
      puts "Aborting."
      exit
    else
      puts "Crawler API SUCCEEDED."
    end
    return api_results_endpoint
  end
  #-- -------------------------------------------------------------------------
  #++


  # Returns the result_list Array (of Hash structures) from the parsed JSON response
  # obtained as running result of the specified Apifier crawler endpoint.
  #
  # Each Hash element of the returned array as the following structure:
  #
  #   {
  #     [ label: season_id label, ] # present only for the "FIN old seasons" crawler
  #     url:     currently processed SOURCE URL for the extracted data,
  #     pageFunctionResult:
  #       [
  #          {
  #            year: year as "YYYY",
  #            month: month as verbose label,
  #            days: "dd-dd" or "dd/dd" or "dd,dd",
  #            city: city name,
  #            description: several possible values:
  #                 - a meeting name, when the "link" is the URL for the meeting manifest
  #                 - "Risultati",    when the "link" is the URL for the meeting results
  #                 - "Start list",   when the "link" is the URL for the meeting start-list
  #            link: the sub-page link for the context in the description;
  #                  (the base address is "http://www.federnuoto.it")
  #          }
  #       ]
  #   }
  #
  # @deprecated
  def get_results_from_apifier_crawler( api_result_endpoint )
    puts "Retrieving results..."
    web_response = get_raw_web_response( api_result_endpoint, true )
# DEBUG
#    puts "\r\n-------------------------[Full web response]----------------------"
#    puts web_response.body
#    puts "------------------------------------------------------------------\r\n"
    return JSON.parse( web_response.body )
  end
  #-- -------------------------------------------------------------------------
  #++


  # POST HTTP(S) for API endpoint.
  # Returns the web response for a specified URI using Net::HTTP.
  # Note that this method may halt the program in case of errors.
  #
  # This method DOES NOT USE RestClient.
  #
  # @param page_link, link to the API endpoint to be called
  #
  def post_raw_web_request( page_link, verbose = false )
    puts "POST '#{page_link}'..." if verbose
    uri = URI( page_link )
    req = Net::HTTP::Post.new( uri )
    res = Net::HTTP.start( uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
      http.request( req )
    end

    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
      return res
    else
      puts "Result NOT-OK or no response! (Result: #{ res.value })\r\nAborting."
    end
  end


  # GET HTTP(S) for API endpoint.
  # Returns the web response for a specified URI using Net::HTTP.
  # Note that this method may halt the program in case of errors.
  #
  # This method DOES NOT USE RestClient.
  #
  # @param page_link, link to the API endpoint to be called
  # @param verbose, true to display an output line showing the request link.
  # @param use_ssl, true to use SSL (for HTTPS connections)
  #
  def get_raw_web_response( page_link, verbose = false )
    puts "GET '#{page_link}'..." if verbose
    uri = URI( page_link )
    res = Net::HTTP.get_response( uri )

    if ! res.is_a?( Net::HTTPSuccess )
      puts "Result NOT-OK (Response: #{ res.inspect })\r\nAborting."
      exit
    end
    return res
  end
  #-- -------------------------------------------------------------------------
  #++


  # Prepares a full, timestamped DB-diff output name, given the destination output
  # base path, its qualifier name and a suffix code.
  #
  def compose_db_diff_filename( output_path, qualifier_name, code )
    file_name = "#{ Time.zone.now.strftime('%Y%m%d%H%M') }#{ qualifier_name }_#{ code }.diff.sql"
    File.join( output_path, file_name )
  end


  # Puts a formatted output of the specified FinCalendar row )
  #
  def printf_fin_calendar_fields( key_id, fin_calendar_row )
    puts "| %35s | %04s | %3s | %06s | %20s | %45s | %40s | %01s | %01s | %01s |" % [
      key_id,
      fin_calendar_row.calendar_year.to_s,
      fin_calendar_row.calendar_month[0..2].to_s,
      fin_calendar_row.calendar_date.to_s,
      fin_calendar_row.calendar_place.to_s,
      fin_calendar_row.calendar_name.to_s,
      fin_calendar_row.goggles_meeting_code,
      (fin_calendar_row.results_link ? 'R' : ''),
      (fin_calendar_row.startlist_link ? 'S' : ''),
      (fin_calendar_row.manifest_link ? 'M' : '')
    ]
  end
  #-- -------------------------------------------------------------------------
  #++

end
# =============================================================================
