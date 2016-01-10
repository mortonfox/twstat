# twstat - Stats charts from downloaded Twitter archives

## Introduction

In December 2012, Twitter
[introduced](http://blog.twitter.com/2012/12/your-twitter-archive.html) a
feature allowing users to download an archive of their entire user timeline. By
February 2013, it was available to all users.

To request your Twitter archive:

1. Visit <https://twitter.com/settings/account>
1. Click on the "Request your archive" button.
1. Wait for an email from Twitter with a download link.

twstat is a Ruby script that generates charts from the data in a Twitter
archive. The output is in the form of a single web page, ready for hosting or
private viewing.

## Prerequisites

To run twstat, you need to install the rubyzip gem. Run `gem install rubyzip`
to add it to your Ruby installation.

The generated web page references the following libraries from online sources:

* jQuery (from [Google Hosted Libraries](https://developers.google.com/speed/libraries/))
* [jQCloud](https://github.com/lucaong/jQCloud) jQuery plugin (from [CDNJS](http://cdnjs.com/))
* [Google Chart Tools](https://developers.google.com/chart/)

## Usage

Run the following command to process your downloaded Twitter archive:

    ruby twstat.rb tweets.zip out.html

Then view out.html in a web browser.

## Sample

You can see a sample charts page here: <http://mortonfox.github.io/twstat/twstat-sample.html>

