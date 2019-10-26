/*
  When using Yarn from the root of the parent Rails application, everything
  should be already ok after a simple 'rails yarn:install'.

  For a manual & standalone install (when using npn, the NodeJS-Package-manager
  as the only package manager):

   > sudo apt-get install nodejs
   > npm install node-fetch --save
   > npm install csv-parser --save
   > npm install fs --save
   > npm install get-stream --save
   > npm install jquery --save
   > npm install util --save
   > npm install puppeteer --save
   > npm install cheerio --save

  Run:
    > node fin-crawler.js


  This needs a 'list.csv' file containing the (editable) list of meeting URLs to be crawled.
  Data fields for the input file (comma separated):

    sourceURL,date,isCancelled,name,place,meetingUrl,year

  File sample (1 line required header + 1 data line):

----8<----
sourceURL,date,isCancelled,name,place,meetingUrl,year
https://www.federnuoto.it/home/master/circuito-supermaster/riepilogo-eventi.html,21/10,,Distanze speciali Lombardia,Brescia,https://www.federnuoto.it/home/master/circuito-supermaster/eventi-circuito-supermaster.html#/risultati/134168:distanze-speciali-master-lombardia.html,"2018"
----8<----

*/

const Csv       = require('csv-parser');
const Fs        = require('fs');
const GetStream = require('get-stream');
const jQuery    = require('jquery');
const Util      = require('util');

const fetch     = require('node-fetch');
const puppeteer = require('puppeteer');
const cheerio   = require('cheerio');

// Function used to read the source file containing the URL list:
// (built up either by hand or by the fin-calendar.js dedicated crawler)
readCSVData = async (filePath) => {
  const parseStream = Csv({delimiter: ','});
  const data = await GetStream.array(Fs.createReadStream(filePath).pipe(parseStream));
  // Retrieve at least the meeting URL from the input file:
  return data.map( row => ({
    url: row['meetingUrl'],
    name: row['name']
  }) );
};


/*
  LOW-LEVEL, PLAIN ES6 sample selection w/ current HTML format:
  Click to show "Male":
     document.querySelectorAll("section#component div:nth-child(3) > ul > li:nth-child(1)")
     => $("section#component li:nth-child(1) > span").click()
  Event titles:
     document.querySelectorAll("section#component div.active > div > h3")
  All link nodes:
     all Male+Female => document.querySelectorAll(".categorie span.collegamento")
     ~ "section#component div.active > div > div:nth-child(2) > span"
*/


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
    // List of URL to process:
    const CSV_FILE = 'list.csv';
    const arrayOfURLs = await readCSVData( CSV_FILE );
    console.log("\r\n*** FIN Results Crawler ***\r\n\r\nParsed list of URLs:");
    console.log( Util.inspect(arrayOfURLs, false, null, true) );

    for (var currURL of arrayOfURLs) {
        console.log(`\r\n\r\nProcessing ${currURL.name}...`);
        const url = currURL.url;
        if (url == '') {
          console.log(`URL is empty. Meeting is probably cancelled or not yet defined. Skipping...`);
        }
        else {
          await processURL( url, browser );
        }
    }
    // Let's close the browser
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
 * @param url the browsed url (for serializing purposes)
 * @param browser a Puppeteer instance
 */
async function processURL( url, browser ) {
  const page = await browser.newPage();
  await page.setViewport({width: 1024, height: 768})
  await page.setUserAgent('Mozilla/5.0')

  console.log(`Browsing to ${url}...`);
  await page.goto(url, {waitUntil: 'networkidle0'});

  // NOT NEEDED anymore (using Cheerio instead & jQuery(currentNode)):
  //console.log('Injecting jQuery...');
  //await page.addScriptTag({path: require.resolve('jquery')});

  console.log('Waiting for list of span-links...');
  const totCount = await page.$$eval('.categorie span.collegamento', spans => spans.length);
  console.log(`Found ${totCount} tot. node links.`);
  console.log('Moving to page.evaluate()...');

  const arrayOfParams = await page.evaluate(() => {
    const spanLinkNodes = document.querySelectorAll(".categorie span.collegamento");
    // Console doesn't work in this synch'ed funct:
    //console.log(`Found ${spanLinkNodes.length} tot. node links.`);
    //console.log( spanLinkNodes[0].innerHTML );
    var data = [];
    for(var i = 0; i < spanLinkNodes.length; i++) {
      const node  = spanLinkNodes[i];
      const params = jQuery(node).data('id').split(';');
      // CURRENT LABELS for variable PARAMS:
      // const labels = jQuery(node).data('value').split(';');
      // => "solr[id_evento];solr[codice_gara];solr[sigla_categoria];solr[sesso]"
      data.push({
        'solr[id_settore]': 1,
        'solr[id_tipologia_1]': 2,
        'solr[corsi_passati]': 0,
        'solr[id_evento]': params[0],
        'solr[codice_gara]': params[1],
        'solr[sigla_categoria]': params[2],
        'solr[sesso]': params[3]
      });
    };
    return data;
  });

  // DEBUG:
  //console.log("\r\n\r\n*** arrayOfParams: ***");
  //console.log( Util.inspect(arrayOfParams, false, null, true) );
  console.log(`Extracted (& prepared) a total of ${arrayOfParams.length} parametric AJAX calls...`);

  const outFileName = getOutputFilenameFromURL( url ) + ".json";
  const htmlContents = await page.content();
  const result = await pageFunction( url, htmlContents, arrayOfParams );

  // DEBUG:
  //console.log("\r\n\r\n*** result: ***");
  //console.log( Util.inspect(result, false, null, true) );
  // DEBUG:
  console.log(`Generating '${outFileName}'...`);

  // stringify JSON Object
  var jsonContent = JSON.stringify( result );

  // DEBUG
  //console.log("\r\nJSON Content:\r\n\r\n--------------------------------------------------------------");
  //console.log(jsonContent);
  //console.log("--------------------------------------------------------------\r\n");

  Fs.writeFile(outFileName, jsonContent, 'utf8', function (err) {
    if (err) {
        console.log("An error occured while writing the JSON Object to the file.");
        return console.log(err);
    }
    console.log("JSON file saved.");
  });
}
//-------------------------------------------------------------------------------------



/*
 * @param url the browsed url (for serializing purposes)
 * @param htmlContents so that cheerio can easily parse the header
 * @param arrayOfParams array of objects params, each one needed for
 *        a single async AJAX call (to request result details on same page)
 *
 * @return the whole array of JSONified result data (header + details) for the specified url
 */
async function pageFunction( url, htmlContents, arrayOfParams ) {
    // Base URL for each ajax detail request (common endpoint for all):
    const urlBase = "https://www.federnuoto.it/index.php?option=com_solrconnect&currentpage=1&view=dettagliorisultati&format=json";
    var sectionData = [], okCount = 0, errorCount = 0, totCount = arrayOfParams.length;

    for (var params of arrayOfParams) {
        await console.log(`\r\nFetching details...`);
        // DEBUG
        //await console.log( Util.inspect(params, true, null, true) ); // show hidden, depth, enable colors
        // POST the request for result details:
        await fetch(urlBase, {
            method: "POST",
            cache: "no-cache",
            headers: { "Content-Type": "application/x-www-form-urlencoded" },
            redirect: "follow",
            body: encodeObjectParamsAsURI( params ) // The body is supposed to be an encoded string of JSON object params
        })
        .then( response => response.json() )
        .then( jsonData => {
            //console.log(`Returning from POST request: ${JSON.stringify(jsonData)}`);
            sectionData.push( extractSectionDetails( jsonData['content'] ) );
            okCount++;
            console.log(`Processed ${okCount}/${totCount} section links.`);
        }).catch( error => {
            console.error(`ERROR: ${error}`);
            sectionData.push({
                retry: params,
                msg: error
            });
            errorCount++;
            console.log(`ERROR on section ${okCount + errorCount}/${totCount}. You'll need to retry this one...`);
        });
    }

    // Return result or partial result in case of error, adding the header to it:
    // (Error request can be found in the result JSON by filtering "retry" rows)
    const result = await buildMeetingInfo(url, htmlContents, sectionData);

    return result;
}
//-------------------------------------------------------------------------------------


/**
 *  Works as jQuery.param(): encodes a (JSON) data Object into a URI component
 */
function encodeObjectParamsAsURI( data ) {
  return Object.keys(data).map(function(k) {
    return encodeURIComponent(k) + '=' + encodeURIComponent(data[k])
  }).join('&');
}
//-------------------------------------------------------------------------------------


/**
 *  Returns a usable filename for the output file
 *  Uses the HTML page name: splits by '/' and takes the ending, removing the '.html' extension
 */
function getOutputFilenameFromURL( url ) {
  const ar = url.split('/');
  return ar[ ar.length-1 ].split(/\.html/i)[0].replace(":", "_");
}
//-------------------------------------------------------------------------------------


/**
 *  FIN Meeting details extractor.
 *
 *  Extracts data from an already expanded (retrieved) result section. (FIN HTML format, 2018-2019+)
 *  Uses cheerio fast parser to retrieve nodes like it was jQuery.
 */
function extractSectionDetails( htmlString ) {
    console.log('Extracting details...');
    // DEBUG
    //console.log("\r\n--------------------------------------------------------------");
    //console.log(htmlString);
    //console.log("--------------------------------------------------------------\r\n");
    var doc$ = cheerio.load(htmlString);
    var sectResult = [];

    const sectionTitle = doc$(".risultati_gara h3").text().trim();
    // DEBUG
    console.log(`Title: ${sectionTitle}`);

    const resultNodes = doc$(".tournament");
    console.log(`resultNodes tot: ${resultNodes.length}`);

    doc$(".tournament").each(function(i, item){
        sectResult.push({
          pos:    doc$(".positions", item).text(),
          name:   doc$(".name", item).text(),
          year:   doc$(".anno", item).text(),
          team:   doc$(".societa", item).text(),
          timing: doc$(".tempo", item).text(),
          score:  doc$(".punteggio", item).text()
        });
    });

    // DEBUG
    //console.log("\r\n--------------------------------------------------------------");
    //console.log(sectResult);
    //console.log("--------------------------------------------------------------\r\n");

    return {
      title: sectionTitle,
      rows:  sectResult
    };
}
//-------------------------------------------------------------------------------------


/**
 *  FIN Meeting HEADER builder + detail append
 *
 *  Extracts data from '.infos' section (FIN HTML format, 2018-2019+) & then adds the sectionData to the resulting object.
 *  Uses cheerio fast parser to retrieve nodes like it was jQuery.
 */
function buildMeetingInfo(url, htmlContents, sectionData = []) {
   // DEBUG
    console.log('Extracting header...');
    var doc$ = cheerio.load( htmlContents );

    return {
      name: doc$('.infos h3').text().trim(),
      meetingURL:   url,
      manifestURL:  doc$(".nat_eve_infos p:contains('Locandina') a").prop('href'),
      dateDay1:     doc$('.nat_eve_dates .nat_eve_date .nat_eve_d').first().text(),
      dateMonth1:   doc$('.nat_eve_dates .nat_eve_date .nat_eve_m').first().text(),
      dateYear1:    doc$('.nat_eve_dates .nat_eve_date .nat_eve_y').first().text(),
      dateDay2:     doc$('.nat_eve_dates .nat_eve_date .nat_eve_d').last().text(),
      dateMonth2:   doc$('.nat_eve_dates .nat_eve_date .nat_eve_m').last().text(),
      dateYear2:    doc$('.nat_eve_dates .nat_eve_date .nat_eve_y').last().text(),
      organization: doc$(".nat_eve_infos p:contains('Organizzazione') .vle").text().trim(),
      venue1:       doc$(".nat_eve_infos p:contains('Impianto') .vle").first().text().trim(),
      address1:     doc$(".nat_eve_infos p:contains('Sede') .vle").first().text().trim(),
      venue2:       doc$(".nat_eve_infos p:contains('Impianto') .vle").length > 1 ? doc$(".nat_eve_infos p:contains('Impianto') .vle").last().text().trim() : '',
      address2:     doc$(".nat_eve_infos p:contains('Sede') .vle").length > 1 ? doc$(".nat_eve_infos p:contains('Sede') .vle").last().text().trim() : '',
      poolLength:   doc$(".nat_eve_infos p:contains('Vasca') .vle").text(),
      timeLimit:    doc$(".nat_eve_infos p:contains('Tempi Limite') .vle").text().trim(),
      registration: doc$(".nat_eve_infos p:contains('Inizio/Chiusura') .vle").text().trim(),
      sections:     sectionData
    };
}
//-------------------------------------------------------------------------------------



/**
 * @NOTUSED / NOT-WORKING
 *
 * Signals to the pre-configured Slack endpoint that this actor is about
 * to end its run.
 */
async function postToSlack( context ) {
    const { request, response, html, $ } = context;
    //const { request, log } = context;
    const urlBase = "https://hooks.slack.com/services/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";
    return await fetch(urlBase, {
        method: "POST",
        body: "payload={\"text\": \"FIN-meeting-detail crawler is about to finish...\"}"
    });
}
//-------------------------------------------------------------------------------------
