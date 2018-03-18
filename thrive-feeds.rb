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

$encoder = HTMLEntities.new

$runFeeds = true

Signal.trap("INT") {
  
  $runFeeds = false
  $feedThread.wakeup
}

$latestItems = {}

# Monkey patch in the originalFeed
module FeedParser
  class Item
    attr_accessor :originalFeed
  end
end

def preprocessItem(item, feed)
  # Try to get rid of script tags if they are there
  item.summary = if item.summary? then
                   item.summary else
                   item.content end.gsub /<script>/i, "&lt;script&gt;"

  # apply processing
  if feed.include?(:preprocess)
    feed[:preprocess].each{|r|
      if r[:title]
        item.title.gsub!(*r[:sub])
      end
    }
  end

  item.originalFeed = feed[:name]
end

def outputItem(feed, file, item)

  file.puts %{<div class="thrive-feed-item thrive-feed-name-#{feed[:name]}">} +
            %{<span class="thrive-feed-icon-#{item.originalFeed}></span>} +
            %{<span class="thrive-feed-title"><span class="thrive-feed-title-main">} +
            %{<a class="thrive-feed-title-link" href="#{item.url}">} +
            $encoder.encode(item.title) + "</a>" +
            %{</span><span class="thrive-feed-by"> by } +
            %{<span class="thrive-feed-author">} +
            $encoder.encode(item.author.to_s.split(' ')[0]) + "</span></span>" + 
            %{<span class="thrive-feed-at"> at <span class="thrive-feed-time">} +
            $encoder.encode(item.published) +
            "</span></span>" +
            %{</span><br><span class="thrive-feed-content">} +
            truncate_html(item.summary, length: if feed.include?(:maxLength) then
                           feed[:maxLength] else 150 end,
                          omission: '...(continued)') +
            %{<br><a class="thrive-feed-item-url" href="#{item.url}">} +
            #%{#{$encoder.encode(item.url)}</a></span></div>}
            %{Read it here</a></span></div>}
end

def outputFeedItems(feed, items)
  File.open(File.join(TargetFolder, feed[:name] + ".html"), 'w'){|file|
    
    itemNum = 0
    
    items.each{|item|

      outputItem feed, file, item
      
      itemNum += 1

      if itemNum >= feed[:maxItems]
        break
      end
    }      
  }
end

def handleURLFeed(feed)

  puts "Retrieving feed: " + feed[:name]

  feedParser = FeedParser::Parser.parse(open(feed[:url]).read)
  items = feedParser.items

  if items.nil?
    puts "Failed to retrieve feed: " + feed[:name]
    return
  end

  # preprocess items
  items.each{|item|
    preprocessItem item, feed
  }

  # Store the items for combines
  $latestItems[feed[:name]] = items

  outputFeedItems feed, items
  
end

def handleCombinedFeed(feed)

  puts "Handling combined feed: " + feed[:name] + " (#{feed[:combine]})"

  # Find all the items
  items = []

  feed[:combine].each{|subfeed|

    if !$latestItems.include?(subfeed)
      puts "Combined feed '#{feed[:name]}' sub feed has no items: " + subfeed
      return
    end
    items += $latestItems[subfeed]
  }

  # Sort them by time
  items = items.sort_by{|i| i.published}.reverse

  # And output
  outputFeedItems feed, items
  
end

$feedThread = Thread.new {

  while $runFeeds
    puts "Processing feeds"

    Feeds.each{|feed|

      if feed.include?(:url)
        
        handleURLFeed feed
        
      elsif feed.include?(:combine)
        
        handleCombinedFeed feed
        
      else
        puts "Unkown feed type: " + feed
        exit 1
      end
    }

    puts "Done handling feeds. Waiting for next run"
    
    # Clear the latest items to save some memory
    $latestItems = {}

    # And allow quitting before waiting
    if !$runFeeds
      break
    end
    
    sleep UpdateEveryNSeconds
  end

  puts "Ended feed parsing thread"
}

$feedThread.join

