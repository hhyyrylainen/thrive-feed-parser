#!/usr/bin/env ruby
# coding: utf-8
# Main file of this project
# Written by Henri Hyyryläinen
require 'logger'
require 'open-uri'
require 'feedparser'
require 'fileutils'
require 'htmlentities'
require 'truncate_html'

include TruncateHtmlHelper

# Configuration
require_relative 'config'

# Suppress tons of messages
LogUtils::Logger[FeedParser::Parser].level = Logger::INFO

FileUtils.mkdir_p TargetFolder

puts "Starting RSS feed to html bot for thrive places"
puts "Writing to folder: #{TargetFolder}"

encoder = HTMLEntities.new

$runFeeds = true

Signal.trap("INT") {
  
  $runFeeds = false
  $feedThread.wakeup
}

$feedThread = Thread.new {

  while $runFeeds
    puts "Processing feeds"

    Feeds.each{|feed|

      feedParser = FeedParser::Parser.parse(open(feed[:url]).read)

      File.open(File.join(TargetFolder, feed[:name] + ".html"), 'w'){|file|

        itemNum = 0
        
        feedParser.items.each{|item|

          # Try to get rid of script tags if they are there
          text = item.summary.gsub /<script>/i, "&lt;script&gt;"

          file.puts "<p>#{encoder.encode(item.title)} by " + encoder.encode(
                      item.author.to_s.split(' ')[0]) + 
                    "<br>" + truncate_html(text, length: 90,
                                           omission: '...(continued)') + 
                    "<br><a href=\"#{item.url}\">#{encoder.encode(item.url)}</a></p>"
          
          ++itemNum

          if itemNum >= feed[:maxItems]
            break
          end
        }      
      }
    }

    puts "Done handling feeds. Waiting for next run"

    # And allow quitting before waiting
    if !$runFeeds
      break
    end
    
    sleep UpdateEveryNSeconds
  end

  puts "Ended feed parsing thread"
}

$feedThread.join

