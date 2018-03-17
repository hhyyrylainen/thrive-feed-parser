#!/usr/bin/env ruby
# coding: utf-8
# Main file of this project
# Written by Henri Hyyryläinen
require 'logger'
require 'open-uri'
require 'feedparser'

# Configuration
require_relative 'config'

# Suppress tons of messages
LogUtils::Logger[FeedParser::Parser].level = Logger::INFO

puts "Starting RSS feed to html bot for thrive places"

$runFeeds = true

Signal.trap("INT") {
  
  $runFeeds = false
  $feedThread.wakeup
}

$feedThread = Thread.new {

  while $runFeeds
    items = []
    
    puts "Fetching feeds..."

    Feeds.each{|feedInfo|

      feedParser = FeedParser::Parser.parse(open(feedInfo[:url]).read)
      items += feedParser.items
    }

    # Skip handling the items if we should quit
    if !$runFeeds
      break
    end

    
    items.each{|item|

      
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

