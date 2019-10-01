/*
  Executes the legacy crawler that retrieves current FIN season Meetings.

  Run:
    > node fin-calendar.js

 */

const Csv       = require('csv-parser');
const Fs        = require('fs');
const GetStream = require('get-stream');
const jQuery    = require('jquery');
const Util      = require('util');

const fetch     = require('node-fetch');
const puppeteer = require('puppeteer');
const cheerio   = require('cheerio');


// TODO Update this to use puppeteer:

/*
  FIN2019-master-list

  Extract current meetings list (list of URL of results).
  startURL: https://www.federnuoto.it/home/master/circuito-supermaster/riepilogo-eventi.html
*/
function pageFunction(context) {
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
  pre-2018 version:
*/
function pageFunction(context) {
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
