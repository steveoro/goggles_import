/*
  === History backup - old crawler pageFunction(), synch version ===
  FIN2019-master-list

  Extract current meetings list (list of URL of results).
  startURL: https://www.federnuoto.it/home/master/circuito-supermaster/riepilogo-eventi.html
*/
function pageFunction_For2018_19_currentMeetings_oldCrawler(context) {
    // called on every page the crawler visits, use it to extract data from it
    var $ = context.jQuery;
    var result = [];

    $("table.records.ris-style").toArray().forEach(function(tableNode) {
      var meetingYear = tableNode.caption.innerText;
      // DEBUG:
      // console.log(tableNode.caption.innerText);

      var tableRowNodes = $(tableNode).children('tbody').first().children('tr').toArray();
      tableRowNodes.forEach(function(tableRowNode) {
        var urlNode = $(tableRowNode).children().last().children()[0];
        result.push({
          year: meetingYear,
          date: $(tableRowNode).children().toArray()[0].innerText,
          name: $(tableRowNode).children().toArray()[1].innerText,
          place: $(tableRowNode).children().toArray()[2].innerText,
          meetingUrl: (urlNode === undefined) ? "" : urlNode.href,
          isCancelled: $(tableRowNode).children().toArray()[3].innerText
        });
      });
    });

    return result;
}
//..............................................................................


/*
  === History backup - old crawler pageFunction(), synch version ===
  pre-2018 version:

  Supermaster_FIN_current_season_meetings
  http://www.federnuoto.it/discipline/master/circuito-supermaster.html
*/
function pageFunction_Pre2018_currentMeetings_oldCrawler(context) {
    // called on every page the crawler visits, use it to extract data from it
    var $ = context.jQuery;
    var result = [];
    var curr_year = '';
    var curr_month = '';

    $('table.calendario tr').each( function() {
        if ( $(this).find('th').first().text() !== '' ) {
            curr_year = $(this).find('th').first().text();
        }
        if ( $(this).find('th').last().text() !== '' ) {
            curr_month = $(this).find('th').last().text();
        }
        var days = $(this).find('td').first().text();
        var city = $(this).find('td:nth-child(3)').first().text();

        $(this).find('a').each( function() {
            var description = $(this).text();
            var link = $(this).attr('href');
            // Add each link to the result list:
            result.push({
                year: curr_year,
                month: curr_month,
                days: days,
                city: city,
                description : description,
                link : link
            });
        });
    });

    return result;
}
//..............................................................................


/*
  === History backup - old crawler pageFunction(), synch version ===
  pre-2018 version:

  Supermaster_FIN_season_172_calendar
  http://www.federnuoto.it/discipline/master/circuito-supermaster/stagione-2017-2018.html
*/
function pageFunction_ForSeason172_oldCrawler(context) {
    // called on every page the crawler visits, use it to extract data from it
    var $ = context.jQuery;
    var result = [];
    var curr_year = '';
    var curr_month = '';

    $('table.calendario tr').each( function() {
        if ( $(this).find('th').first().text() !== '' ) {
            curr_year = $(this).find('th').first().text();
        }
        if ( $(this).find('th').last().text() !== '' ) {
            curr_month = $(this).find('th').last().text();
        }
        var days = $(this).find('td').first().text();
        var city = $(this).find('td:nth-child(3)').first().text();

        $(this).find('a').each( function() {
            var description = $(this).text();
            var link = $(this).attr('href');
            // Add each link to the result list:
            result.push({
                year: curr_year,
                month: curr_month,
                days: days,
                city: city,
                description : description,
                link : link
            });
        });
    });

    return result;
}
//..............................................................................


/*
  === History backup - old crawler pageFunction(), synch version ===
  pre-2018 version:

  Vimercate_ASD_FIN_Meetings
  - 2009: http://www.vimercatenuoto.org/rmaster09.htm
  - 2010: http://www.vimercatenuoto.org/rmaster10.htm
  - 2011: http://www.vimercatenuoto.org/rmaster11.htm
  - 2012: http://www.vimercatenuoto.org/rmaster12.htm
*/
function pageFunction_ForMiscSeasons_VimercateASD_oldCrawler(context) {
    // called on every page the crawler visits, use it to extract data from it
    var $ = context.jQuery;
    var result = [];

    $('a').each( function() {
        var description = $(this).text().trim();
        var link = $(this).attr('href');
        // Add each link to the result list if it's a result link:
        if ( link.match( /master\/risultati/i ) ) {
            result.push({
                description : description,
                link : link
            });
        }
    });
    return result;
}
//..............................................................................
