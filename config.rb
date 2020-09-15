# frozen_string_literal: true

GITHUB_FEED_TOKEN = ENV['GITHUB_FEED_TOKEN'] || ''

# Modify the feed parameters here
FEEDS = [
  {
    name: 'devforum-posts',
    url: 'https://forum.revolutionarygamesstudio.com/posts.rss',
    save_as_is: true,
    maxItems: 10
  },
  {
    name: 'mainsite-posts',
    url: 'https://revolutionarygamesstudio.com/feed/',
    save_as_is: true,
    maxItems: 1
  },
  unless GITHUB_FEED_TOKEN.empty?
    {
      name: 'github-revolutionarygames',
      url: 'https://github.com/organizations/Revolutionary-Games/' \
        "revolutionary-bot.private.atom?token=#{GITHUB_FEED_TOKEN}",
      maxItems: 20,
      allowNoSummary: true,
      preprocess:
        [
          {
            title: true,
            sub: [/\w+\scommented/i, 'New comment']
          },
          {
            title: true,
            sub: [/\w+\sclosed an issue/i, 'Issue closed']
          },
          {
            title: true,
            sub: [/\w+\sopened a pull request/i, 'New pull request']
          },
          {
            title: true,
            sub: [/\w+\sforked .+ from/i, 'New fork of']
          },
          {
            title: true,
            sub: [/\w+\spushed/i, 'New commits']
          },
          {
            title: true,
            sub: [/\w+\sopened an issue/i, 'New issue']
          },
          {
            summary: true,
            sub: [/data-(hydro|ga|)-click[\w\-]*="[^"]*"/i, '']
          },
          {
            summary: true,
            sub: [%r{<svg .*>.*</svg>}i, '']
          }
        ]
    }
  end,
  {
    name: 'community-announcements',
    url: 'https://community.revolutionarygamesstudio.com/c/announcements.rss',
    maxItems: 1,
    maxLength: 400
  },
  unless GITHUB_FEED_TOKEN.empty?
    # Combined feed
    {
      name: 'devforum-and-github',
      combine: %w[devforum-posts github-revolutionarygames],
      maxItems: 30
    }
  end
].reject(&:nil?)

# Time to wait after parsing feeds is complete before doing again
UPDATE_EVERY_N_SECONDS = 900

TARGET_FOLDER = ENV['TARGET_FOLDER'] || './html'
