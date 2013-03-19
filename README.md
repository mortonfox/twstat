# twstat - Stats charts from downloaded Twitter archives

## Purpose

In February 2013, Twitter introduced a feature allowing users to download an archive of their entire user timeline. You can request this archive from Twitter by visiting their web interface and selecting gear, settings, and "Request your archive". 

twstat is a Ruby script that generates charts from the data in a Twitter archive.

## Prerequisites

To run twstat, you need to install the following:
* The rubyzip gem. Run `gem install rubyzip` to add it to your Ruby installation.
* The jQCloud jQuery plugin. Download it from [https://github.com/lucaong/jQCloud](https://github.com/lucaong/jQCloud)

The generated HTML code also references the following libraries directly from online sources:
* jQuery 
* [Google Chart Tools](https://developers.google.com/chart/) but the two libraries are loaded directly from online sources.

## Usage

Run the following command to process your downloaded Twitter archive: 

    ruby twstat.rb tweets.zip out.html
       
Then view out.html in a web browser.
