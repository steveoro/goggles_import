# Goggles -o^o-
## Data-Import tools suite


Goggles is a Rails application developed to manage and browse the results obtained
dynamically from any official Swimming competition. The app is designed also to handle
a lot more, as long as is related to Swimming.

This Project covers the new data-import utility and is designed for internal usage only, together with the original `Admin` application.

Official framework Wiki, [here](https://github.com/steveoro/goggles_admin/wiki)



### Dependencies & setup:

- [Goggles Core, for data structures](https://github.com/steveoro/goggles_core)
- [Kiba, for ETL](https://github.com/thbar/kiba)
- Yarn, as main ES6 package manager, for installation see [Yarn package manager](https://yarnpkg.com/lang/en/docs/install/#debian-stable)
- NodeJS + other packages for the data crawler tool: just run a `rails yarn:install` and everything should be taken care of (after Yarn has been installed).



### Internal custom Crawler:

Basic dependencies installation (from Rails app root):

```bash
   > rails yarn:install
```

Run (for example, the FIN crawler):

```bash
   > cd crawler
   > node fin-crawler.js
```

This will expect a `list.csv` file containing the (editable) list of meeting URLs to be crawled.

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
