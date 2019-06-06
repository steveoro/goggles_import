# Goggles -o^o-
## Data-Import tools suite


Goggles is a Rails application developed to manage and browse the results obtained
dynamically from any official Swimming competition. The app is designed also to handle
a lot more, as long as is related to Swimming.

This Project covers the new data-import utility and is designed for internal usage only, together with the original `Admin` application.

Official framework Wiki, [here](https://github.com/steveoro/goggles_admin/wiki)



### Dependencies:

- [Goggles Core, for data structures](https://github.com/steveoro/goggles_core)
- [Kiba, for ETL](https://github.com/thbar/kiba)
- NodeJS + other packages for the data crawler tool (see below)



### Internal custom Crawler:

Basic dependencies installation:

```bash
   > sudo apt-get install nodejs
   > npm install node-fetch --save
   > npm install csv-parser --save
   > npm install fs --save
   > npm install get-stream --save
   > npm install jquery --save
   > npm install util --save
   > npm install puppeteer --save
   > npm install cheerio --save
```

Run (for example, the FIN crawler):

```bash
   > cd crawler
   > node fin-crawler.js
```

This will need a `list.csv` file containing the (editable) list of meeting URLs to be crawled.
The crawler will start looping on all URLs found in the `.csv` file, extracting data and will produce a `.json` file for each meeting result page crawled.
Each JSON file will be created in the current running directory (`crawler`) and have as its filename a semi-normalized meeting name with a prefixed unique code.

Data fields for the `list.csv` input file (comma separated):

    `URL`,`date`,`isCancelled`,`name`,`place`,`meetingUrl`,`year`

File sample (1 line required header + 1 data line):

```
----8<----
URL,date,isCancelled,name,place,meetingUrl,year
https://www.federnuoto.it/home/master/circuito-supermaster/riepilogo-eventi.html,21/10,,Distanze speciali Lombardia,Brescia,https://www.federnuoto.it/home/master/circuito-supermaster/eventi-circuito-supermaster.html#/risultati/134168:distanze-speciali-master-lombardia.html,"2018"
----8<----
```

The data-crawl resulting files should be moved by hand to the `data.new` folder before being processed by Kiba.

