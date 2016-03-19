# SEC DataGrinder

This application downloads corporate ownership data from the SEC's Edgar web app and processes it into summaries by company. It also associates the ownership data with political donations and lobbying data from http://opensecrets.org.

### SEC:

- Downloads list of all forms submitted to the SEC starting at 1990 from the SEC's EDGAR:

https://www.sec.gov/edgar/searchedgar/legacy/companysearch.html

- Download all corporate ownership-related forms (SEC form SC-13D, SC-13G, 3, 4 and 5) for a given year range
- Process forms into 'major owners' (SC-13D, SC-13G) and 'direct owners' (3, 4, 5)
- Process major and direct owner tables into a unified corporate ownership summary in MySQL

### OpenSecrets:

Imports 527, lobbying and campaign data into MySQL:

https://www.opensecrets.org/MyOS/bulk.php

### CorpWatch:

Imports company subsidiaries data into MySQL:

http://api.corpwatch.org/documentation/db_dump/

These 3 databases are then linked: corporate ownership plus campaign finance data along with lists of each company's subsidiaries.

## Installation

DataGrinder must be run on either a Mac or Linux box, the author uses a custom Hackintosh tower: 3.79 GHz Intel Quad-Core i5 with 24GB of RAM.

### Prerequisites

You'll definitely need an app for browsing the mysql / mongodb data. Author uses:

```
http://www.sequelpro.com/download
http://app.robomongo.org/download.html
```

- Install mysql. Any version should work, author used 5.5: https://dev.mysql.com/downloads/mysql/
- Install mongodb, author used 3.0.8: https://www.mongodb.org/downloads#production

Make sure you have *plenty* of hard drive space available wherever you install mysql/mongodb, I'd budget at least 200gb if you're processing all the available data.  The more RAM you have the faster it will go, 16GB is probably the bare minimum.

- Create DBs, start Rails

```
bundle install
rake db:create
rake db:migrate
```

## How To Use #1: SEC data

Once setup, there are now a number of rake tasks to run.

### SEC.1: rake sec:get_indices

Open ./Rakefile in your favorite text editor.

Find the 'get_indices' task. Enter the years you'd like to import as the first two parameters to Sec::get_indices. The earliest year supported by datagrinder is 1994.

The SEC keeps an 'index' of all forms that have been submitted by year, these must be downloaded first so we know what corporate ownership forms to download in the next step.

```
rake sec:get_indices
```

### SEC.2: rake sec:import_forms

In Rakefile, find import_forms and change the years/quarters to match the ones downloaded in step 1.

```
rake sec:import_forms
```

### SEC.3: rake sec:download_forms

This one takes forever. For each record we created in SEC.2, download the form data itself into our mongodb record in the 'txt' field. This takes maybe 1-12 hours per quarter, depending on your internet speed. A wired internet connection is *highly* recommended.

To speed things along, I run multiple download processes at once in separate tabs:

```
rake sec:download_forms year=1994 qtr=1
rake sec:download_forms year=1994 qtr=2
rake sec:download_forms year=1994 qtr=3
rake sec:download_forms year=1994 qtr=4
```

### SEC.4: rake sec:parse_owners

With the forms downloaded, we now parse them into 'major owners' of 5% or more (the SC forms) and 'direct owners' (forms 3, 4, 5).

Once again, make sure the years and quarters are configured correctly in Rakefile.

This is the meat of the original programming for this project, dealing with the absolutely horrific state of the SC forms' formatting and managing to still extract the ownership data.  For an idea of how different they can be, check these out:

```
https://www.sec.gov/Archives/edgar/data/61986/0000734269-94-000014.txt
https://www.sec.gov/Archives/edgar/data/902320/0000950144-94-000447.txt
```

### SEC.5: rake sec:create_summaries

Now that the direct_owners and major_owners collections are populated, we can turn them into summaries, one for each unique owner.

This task creates the empty summary records in the mysql table 'summaries'.

### SEC.6: rake sec:populate_summaries

Populates the summary fields 'owned_by_insider', 'owned_by_5percent', 'owner_of_insider', 'owner_of_5percent' based on the major-owners and direct_owners collections.

### SEC.7: rake sec:populate_subsidiaries

Populates summary.subsidiaries, based on CorpWatch's subsidiary data.

When this is finished, the corporate ownership summaries are complete!

Now we move on to campaign finance

### OS.1: rake sec:opensecrets_create_tables

This must be run three times, specifying a different set of tables to import each time:

- 527
- lobby
- campaign

### OS.2: rake sec:populate_os_summary_donor

OpenSecrets summarization

### OS.3: rake sec:populate_os_summary_org

OpenSecrets summarization

### Final: rake sec:import_export

Follow the instructions herein to export the summary data and import it on another server.

# Methodology:

- Read in Edgar's 'index' files to create the 'forms' MongoDB collection
- For each form, download the text data into the forms.txt field
- Process each form, extracting owners
- Create ownership 'summary' entries in MySQL for each company and owner
- Populate summaries using owner tables

## Anticipated questions:

Q: Why is it both mongoid and mysql?
A: There's two types of data: 30 gigs of unstructured weirdness (mongo) and the nicely structured summary data (mongodb, about 300mb).

Q: Why is it a Rails app?
A: Mostly for the Mongoid niceties, and I'm just generally used to them.

## More detail on the data

This app processes 6 forms:

Forms 3, 4 or 5. These are required to be filed by 'insiders', or employees at a given company when they acquire or dispose of shares. These end up in the direct_owners collection in MongoDB.

Forms SC 13D, SC 13G and SC 13G/A. These are required to be filed by anyone who owns 5%+ or more of a given company when they acquire or dispose of shares. These end up in the major_owners collection.

# Quirks and Inaccuracies

We ignore 'direct owners' for data before 2004 Quarter 4. The reason is, before this date the data is freeform and extremely difficult to parse out, and nice clean XML afterwards. Realistically employees own very small amount of the company's stock, and employee information from 12+ years ago is likely to be out of date. If they're still employed at the company, it's very likely that their stock ownership has changed since then and thus will appear in our DB.
