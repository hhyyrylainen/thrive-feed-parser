#!/usr/bin/env ruby
# frozen_string_literal: true

# Main file of this project
# Written by Henri Hyyryläinen
require 'logger'
require 'open-uri'
require 'feedparser'
require 'fileutils'
require 'htmlentities'
require 'truncate_html'
require 'uri'

# Configuration
require_relative 'config'

# Suppress tons of messages
LogUtils::Logger[FeedParser::Parser].level = Logger::INFO

FileUtils.mkdir_p TARGET_FOLDER

puts 'Starting RSS feed to html bot for thrive places'
puts "Writing to folder: #{TARGET_FOLDER}"

$encoder = HTMLEntities.new

$runFeeds = true

Signal.trap('INT') do
  $runFeeds = false
  $feedThread.wakeup
end

$latestItems = {}

# Monkey patch in the original_feed
module FeedParser
  # Target monkey patch class
  class Item
    attr_accessor :original_feed
  end
end

# Safely writes out file content
def write_file_safe(file, content)
  target = File.join(TARGET_FOLDER, file)
  temp = target + '.tmp'
  File.write temp, content

  File.rename temp, target
end

# Main class handling this stuff
class ThriveFeedParser
  include TruncateHtmlHelper

  def initialize(feed)
    @feed = feed
  end

  def check_summary(item)
    # Have some content on all feeds if they are not allowed to be empty
    unless item.summary?

      item.summary = if !@feed[:allowNoSummary]
                       item.content
                     else
                       ''
                     end
    end

    # Try to get rid of script tags if they are there
    item.summary.gsub!(/<script>/i, '&lt;script&gt;')
  end

  def preprocess_item(item)
    check_summary item

    # apply processing
    if @feed.include?(:preprocess)
      @feed[:preprocess].each do |r|
        item.title.gsub!(*r[:sub]) if r[:title]
        item.summary.gsub!(*r[:sub]) if r[:summary]
      end
    end

    item.original_feed = @feed[:name]
  end

  def output_item(file, item)
    file.puts %(<div class="thrive-feed-item thrive-feed-name-#{@feed[:name]}">) +
              %(<span class="thrive-feed-icon-#{item.original_feed}"></span>) +
              %(<span class="thrive-feed-title"><span class="thrive-feed-title-main">) +
              %(<a class="thrive-feed-title-link" href="#{item.url}">) +
              $encoder.encode(item.title) + '</a>' +
              %(</span><span class="thrive-feed-by"> by ) +
              %(<span class="thrive-feed-author">) +
              $encoder.encode(item.author.to_s.split(' ')[0]) + '</span></span>' +
              %(<span class="thrive-feed-at"> at <span class="thrive-feed-time">) +
              $encoder.encode(item.published) +
              '</span></span>' +
              %(</span><br><span class="thrive-feed-content">) +
              truncate_html(item.summary, length: if @feed.include?(:maxLength)
                                                    @feed[:maxLength] else 150 end,
                                          omission: '...(continued)') +
              %(<br><a class="thrive-feed-item-url" href="#{item.url}">) +
              # %{#{$encoder.encode(item.url)}</a></span></div>}
              %(Read it here</a></span></div>)
  end

  def output_feed_items(items)
    target = File.join(TARGET_FOLDER, @feed[:name] + '.html')
    temp = target + '.tmp'
    File.open(temp, 'w') do |file|
      item_num = 0

      items.each do |item|
        output_item file, item

        item_num += 1

        break if item_num >= @feed[:maxItems]
      end
    end

    File.rename temp, target
  end

  def handle_url_feed
    puts 'Retrieving feed: ' + @feed[:name]

    uri = URI.parse(@feed[:url])
    feed_data = URI.open(@feed[:url]).read

    write_file_safe uri.path.gsub(%r{/}, ''), feed_data if @feed[:save_as_is]

    feed_parser = FeedParser::Parser.parse(feed_data)
    items = feed_parser.items

    if items.nil?
      puts 'Failed to retrieve feed: ' + @feed[:name]
      return
    end

    # preprocess items
    items.each do |item|
      preprocess_item item
    end

    # Store the items for combines
    $latestItems[@feed[:name]] = items

    output_feed_items items
  end

  def handle_combined_feed
    puts 'Handling combined feed: ' + @feed[:name] + " (#{@feed[:combine]})"

    # Find all the items
    items = []

    @feed[:combine].each do |subfeed|
      unless $latestItems.include?(subfeed)
        puts "Combined feed '#{@feed[:name]}' sub feed has no items: " + subfeed
        next
      end
      items += $latestItems[subfeed]
    end

    # Sort them by time
    items = items.sort_by(&:published).reverse

    # And output
    output_feed_items items
  end
end

$feedThread = Thread.new do
  while $runFeeds
    puts 'Processing feeds'

    FEEDS.each do |feed|
      parser = ThriveFeedParser.new feed

      if feed.include?(:url)

        parser.handle_url_feed

      elsif feed.include?(:combine)

        parser.handle_combined_feed

      else
        puts 'Unkown feed type: ' + feed
        exit 1
      end
    end

    puts 'Done handling feeds. Waiting for next run'

    # Clear the latest items to save some memory
    $latestItems = {}

    # And allow quitting before waiting
    break unless $runFeeds

    sleep UPDATE_EVERY_N_SECONDS
  end

  puts 'Ended feed parsing thread'
end

$feedThread.join
