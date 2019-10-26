/*
  Executes the legacy crawler that retrieves the list of the current FIN season Meetings
  and produces a CSV file with a line for each meeting.

  Run:
    > node fin-calendar.js


  Resulting file sample (1 line required header + 1 data line):

----8<----
sourceURL,date,isCancelled,name,place,meetingUrl,year
https://www.federnuoto.it/home/master/circuito-supermaster/riepilogo-eventi.html,21/10,,Distanze speciali Lombardia,Brescia,https://www.federnuoto.it/home/master/circuito-supermaster/eventi-circuito-supermaster.html#/risultati/134168:distanze-speciali-master-lombardia.html,"2018"
----8<----

  The resulting file output can be used as input for:

  - fin-crawler.js => crawls each meetingUrl to build up a separate JSON file with the results from the meeting
  - fin-calendar rake task => updates/recreates the current FIN calendar based on the contents of the source file
 */

const Csv       = require('csv-parser');
const Fs        = require('fs');
const GetStream = require('get-stream');
const jQuery    = require('jquery');
const Util      = require('util');

const fetch     = require('node-fetch');
const puppeteer = require('puppeteer');
const cheerio   = require('cheerio');

// Calendar source URL:
// (this typically hasn't changed in years, but may be parametrized in future versions)
const startURL  = "https://www.federnuoto.it/home/master/circuito-supermaster/riepilogo-eventi.html";


// Ignore TLS self-signed certificates & any unauth. certs: (Not secure, but who cares for crawling...)
process.env["NODE_TLS_REJECT_UNAUTHORIZED"] = 0;


puppeteer
  .launch({
    headless: true,
    args: [
      '--ignore-certificate-errors', '--enable-feature=NetworkService',
      '--no-sandbox', '--disable-setuid-sandbox'
    ]
  })
  .then( async browser => {
    console.log(`\r\n*** FIN Calendar Crawler ***\r\n\r\nProcessing ${startURL}...`);
    await processPage( startURL, browser );
    await browser.close();
    process.exit();
  })
  .catch(function(error) {
    console.error('ERROR:');
    console.error( error.toString() );
    process.exit();
  });
//-----------------------------------------------------------------------------


/*
 * Asynch pageFunction for retrieving the FIN calendar from the list of current events
 * from the current season.
 *
 * Supports 2018+ FIN website styling.
 *
 * @param baseURL the browsed url (for serializing purposes)
 * @param browser a Puppeteer instance
 */
async function processPage( baseURL, browser ) {
  const page = await browser.newPage();
  await page.setViewport({width: 1024, height: 768})
  await page.setUserAgent('Mozilla/5.0')

  console.log(`Browsing to ${baseURL}...`);
  await page.goto(baseURL, {waitUntil: 'networkidle0'});

  console.log('Waiting for table nodes rendering...');
  const totCount = await page.$$eval('table.records.ris-style', tableNodes => tableNodes.length);
  console.log(`Found ${totCount} tot. nodes.`);
  console.log('Moving to page.evaluate()...');

  const csvContents = await page.evaluate(() => {
    const tableNodes = document.querySelectorAll("table.records.ris-style");
    const url = document.location;
    var csvText = "startURL,date,isCancelled,name,place,meetingUrl,year\r\n";
    for(var i = 0; i < tableNodes.length; i++) {
        const tableNode = tableNodes[i];
        const meetingYear = tableNode.caption.innerText;
        const tableRowNodes = $(tableNode).children('tbody').first().children('tr').toArray();
        tableRowNodes.forEach(function(tableRowNode) {
          const urlNode = $(tableRowNode).children().last().children()[0];
          const date    = $(tableRowNode).children().toArray()[0].innerText;
          const name    = $(tableRowNode).children().toArray()[1].innerText;
          const place   = $(tableRowNode).children().toArray()[2].innerText;
          const meetingUrl  = (urlNode === undefined) ? "" : urlNode.href;
          const isCancelled = $(tableRowNode).children().toArray()[3].innerText;
          csvText = csvText.concat(`${url},${date},${isCancelled},${name},${place},${meetingUrl},${meetingYear}\r\n`);
        });
    };
    return csvText;
  });
  console.log(`Events table parsing done.`);
  // DEBUG
  // console.log("\r\nCSV Contents:\r\n\r\n--------------------------------------------------------------");
  // console.log(csvContents);
  // console.log("--------------------------------------------------------------\r\n");

  const outFileName = (new Date()).toISOString().split('T')[0] + "-FIN-full_meeting_URLs.csv";
  console.log(`Generating '${outFileName}'...`);
  Fs.writeFile(outFileName, csvContents, 'utf8', function (err) {
    if (err) {
      console.log("An error occured while writing the CSV text to the file.");
      return console.log(err);
    }
    console.log("CSV file saved.\r\nDone.");
  });
}
//-------------------------------------------------------------------------------------
