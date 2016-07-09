#!/usr/bin/env ruby

# Process a Twitter archive file and generate a page of stats and charts.
# Author: Po Shan Cheah http://mortonfox.com

require 'csv'
require 'erb'
require 'date'
require 'time'
require 'zip'
require 'ostruct'

# Process a Twitter Archive file.
class TweetStats
  COUNT_DEFS = {
    alltime: { title: 'all time', days: nil, },
    last30: { title: 'last 30 days', days: 30, },
  }.freeze

  MENTION_REGEX = /\B@([A-Za-z0-9_]+)/
  STRIP_A_TAG = %r{<a[^>]*>(.*)</a>}

  COMMON_WORDS = %w(
    the and you that
    was for are with his they
    this have from one had word
    but not what all were when your can said
    there use each which she how their
    will other about out many then them these
    some her would make like him into time has look
    two more write see number way could people
    than first water been call who oil its now
    find long down day did get come made may part
    http com net org www https
  ).freeze

  COLORS = %w(
    #673AB7 #3F51B5 #2196F3
    #009688 #4CAF50 #FF5722
    #E91E63
  ).freeze

  attr_reader :row_count

  # Make a hash of counters, i.e. values default to 0 the first time.
  def counter_hash
    Hash.new { |h, k| h[k] = 0 }
  end

  def initialize
    @count_by_month = counter_hash

    @all_counts = {}
    COUNT_DEFS.keys.each { |period|
      @all_counts[period] = {
        by_dow: counter_hash,
        by_hour: counter_hash,
        by_mention: counter_hash,
        by_source: counter_hash,
        by_word: counter_hash
      }
    }

    @row_count = 0
    @newest_tstamp = nil
    @oldest_tstamp = nil
  end

  PROGRESS_INTERVAL = 2500

  # Archive entries before this point all have 00:00:00 as the time, so don't
  # include them in the by-hour chart.
  ZERO_TIME_CUTOFF = Time.new(2010, 11, 4, 21)

  def process_row row
    @row_count += 1

    # Skip malformed/short rows.
    return if row.size < 8

    tstamp_str = row['timestamp']
    source_str = row['source']
    tweet_str = row['text']
    tstamp = Time.parse tstamp_str

    if @row_count % PROGRESS_INTERVAL == 0
      print "Processing row #{@row_count} (#{tstamp.strftime '%Y-%m-%d'}) ...\r"
      $stdout.flush
    end

    # Save the newest timestamp because any last N days stat refers to N
    # days prior to this timestamp, not the current time.
    # This assumes that tweets.csv is ordered from newest to oldest.
    unless @newest_tstamp
      @newest_tstamp = tstamp

      COUNT_DEFS.each { |_period, periodinfo|
        periodinfo[:cutoff] = nil
        periodinfo[:cutoff] = @newest_tstamp - periodinfo[:days] * 24 * 60 * 60 if periodinfo[:days]
      }
    end

    # This assumes that tweets.csv is ordered from newest to oldest.
    @oldest_tstamp = tstamp

    mon_key = [format('%04d-%02d', tstamp.year, tstamp.mon), tstamp.year, tstamp.mon]
    @count_by_month[mon_key] += 1

    mentions = tweet_str.scan(MENTION_REGEX).map { |match| match[0].downcase }
    source = source_str.gsub(STRIP_A_TAG, '\1')

    # This is for Ruby 1.9 when reading from ZIP file.
    tweet_str.force_encoding 'utf-8' if tweet_str.respond_to? :force_encoding

    # The gsub() converts Unicode right single quotes to ASCII single quotes.
    # This works in Ruby 1.8 as well.
    words = tweet_str.gsub(['2019'.to_i(16)].pack('U*'), "'").downcase.split(/[^a-z0-9_']+/).select { |word|
      word.size >= 3 && !COMMON_WORDS.include?(word)
    }

    COUNT_DEFS.each { |period, periodinfo|
      next if periodinfo[:cutoff] && tstamp < periodinfo[:cutoff]

      period_counts = @all_counts[period]

      # Archive entries before this point all have 00:00:00 as the time, so
      # don't include them in the by-hour chart.
      period_counts[:by_hour][tstamp.hour] += 1 if tstamp >= ZERO_TIME_CUTOFF

      period_counts[:by_dow][tstamp.wday] += 1

      mentions.each { |mentioned_user|
        period_counts[:by_mention][mentioned_user] += 1
      }

      period_counts[:by_source][source] += 1

      words.each { |word|
        period_counts[:by_word][word] += 1
      }
    }
  end

  def report_title str
    puts
    puts str
    puts '=' * str.size
  end

  DOWNAMES = %w( Sun Mon Tue Wed Thu Fri Sat ).freeze

  def report
    report_title 'Tweets by Month'
    @count_by_month
      .sort_by { |month, _count| month.first }
      .each { |month, count| puts "#{month.first}: #{count}" }

    COUNT_DEFS.each { |period, periodinfo|
      report_title "Tweets by Day of Week (#{periodinfo[:title]})"
      0.upto(6) { |dow|
        puts "#{DOWNAMES[dow]}: #{@all_counts[period][:by_dow][dow]}"
      }
    }

    COUNT_DEFS.each { |period, periodinfo|
      report_title "Tweets by Hour (#{periodinfo[:title]})"
      0.upto(23) { |hour|
        puts "#{hour}: #{@all_counts[period][:by_hour][hour]}"
      }
    }

    COUNT_DEFS.each { |period, periodinfo|
      report_title "Top mentions (#{periodinfo[:title]})"
      @all_counts[period][:by_mention]
        .sort_by { |_user, count| -count }
        .first(10)
        .each { |user, count| puts "@#{user}: #{count}" }
    }

    COUNT_DEFS.each { |period, periodinfo|
      report_title "Top clients (#{periodinfo[:title]})"
      @all_counts[period][:by_source]
        .sort_by { |_source, count| -count }
        .first(10)
        .each { |source, count| puts "#{source}: #{count}" }
    }

    COUNT_DEFS.each { |period, periodinfo|
      report_title "Top words (#{periodinfo[:title]})"
      @all_counts[period][:by_word]
        .sort_by { |_word, count| -count }
        .first(20)
        .each { |word, count| puts "#{word}: #{count}" }
    }
  end

  def make_tooltip category, count
    "<div class=\"tooltip\"><strong>#{category}</strong><br />#{count} tweets</div>"
  end

  def report_html outfname
    erb_data = OpenStruct.new

    month_counts = @count_by_month.sort_by { |month, _count| month[0] }
    erb_data.by_month_data =
      month_counts
      .map
      .with_index { |(mon, count), i| "[new Date(#{mon[1]}, #{mon[2] - 1}), #{count}, '#{make_tooltip mon[0], count}', '#{COLORS[i % 6]}']" }
      .join ",\n"
    first_month_rec = month_counts.first.first
    first_mon = Date.civil(first_month_rec[1], first_month_rec[2], 15) << 1
    last_month_rec = month_counts.last.first
    last_mon = Date.civil(last_month_rec[1], last_month_rec[2], 15)
    erb_data.by_month_min = [first_mon.year, first_mon.mon - 1, first_mon.day].join ','
    erb_data.by_month_max = [last_mon.year, last_mon.mon - 1, last_mon.day].join ','

    erb_data.by_dow_data = {}
    COUNT_DEFS.each { |period, _periodinfo|
      period_counts_by_dow = @all_counts[period][:by_dow]
      erb_data.by_dow_data[period] = 0.upto(6).map { |dow|
        "['#{DOWNAMES[dow]}', #{period_counts_by_dow[dow].to_i}, '#{make_tooltip DOWNAMES[dow], period_counts_by_dow[dow].to_i}', '#{COLORS[dow]}']"
      }.join ",\n"
    }

    erb_data.by_hour_data = {}
    COUNT_DEFS.each { |period, _periodinfo|
      period_counts_by_hour = @all_counts[period][:by_hour]
      erb_data.by_hour_data[period] = 0.upto(23).map { |hour|
        "[#{hour}, #{period_counts_by_hour[hour].to_i}, '#{make_tooltip "Hour #{hour}", period_counts_by_hour[hour].to_i}', '#{COLORS[hour % 6]}']"
      }.join ",\n"
    }

    erb_data.by_mention_data = {}
    COUNT_DEFS.each { |period, _periodinfo|
      erb_data.by_mention_data[period] =
        @all_counts[period][:by_mention]
        .sort_by { |_user, count| -count }
        .first(10)
        .map
        .with_index { |(user, count), i| "[ '@#{user}', #{count}, '#{COLORS[i % COLORS.size]}' ]" }
        .join ",\n"
    }

    erb_data.by_source_data = {}
    COUNT_DEFS.each { |period, _periodinfo|
      erb_data.by_source_data[period] =
        @all_counts[period][:by_source]
        .sort_by { |_source, count| -count }
        .first(10)
        .map
        .with_index { |(source, count), i| "[ '#{source}', #{count}, '#{COLORS[i % COLORS.size]}' ]" }
        .join ",\n"
    }

    erb_data.by_words_data = {}
    COUNT_DEFS.each { |period, _periodinfo|
      erb_data.by_words_data[period] =
        @all_counts[period][:by_word]
        .sort_by { |_word, count| -count }
        .first(100)
        .map { |word, count| "{text: \"#{word}\", weight: #{count} }" }
        .join ",\n"
    }

    erb_data.subtitle = "from #{@oldest_tstamp.strftime '%Y-%m-%d'} to #{@newest_tstamp.strftime '%Y-%m-%d'}"

    # Add custom colors to the word clouds.
    erb_data.extra_css = 0.upto(9).map { |i|
      ".w#{10 - i} { color: #{COLORS[i % COLORS.size]} !important; }"
    }.join("\n")

    template = ERB.new File.new("#{File.dirname(__FILE__)}/twstat.html.erb").read
    File.open(outfname, 'w') { |f|
      f.puts template.result erb_data.instance_eval { binding }
    }
  end
end

# Process a file. This function will handle the detail of whether to process
# tweets.csv from inside a zip file or the file itself.
# Accepts a block that will be called once for each CSV row.
def process_file infile, &blk
  if infile =~ /\.zip$/i
    Zip::File.open(infile) { |zipf|
      zipf.get_input_stream('tweets.csv') { |f|
        CSV.parse(f, headers: true, &blk)
      }
    }
  else
    CSV.foreach(infile, headers: true, &blk)
  end
end

def main
  progname = File.basename $PROGRAM_NAME
  usage = <<-EOM
Parse a Twitter archive and produce a web page with stats charts.

Usage: #{progname} input-file output-file

input-file:
    Input file name. This could either be:
      - The tweets.zip file that you downloaded from Twitter, or
      - The CSV file from the root of tweets.zip if you've unpacked it
        manually.

output-file:
    This is the name of the HTML file to which to write the result.
  EOM

  if ARGV.size < 2
    warn usage
    exit 2
  end

  infile, outfile = ARGV

  twstat = TweetStats.new

  begin
    process_file(infile) { |row|
      twstat.process_row row
    }
  rescue => err
    warn "Error after reading row #{twstat.row_count}: #{err}"
    warn err.backtrace
    exit 1
  end

  puts "\nFinished processing."
  twstat.report_html outfile
  # twstat.report
end

main

__END__
