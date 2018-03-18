GithubFeedToken = ENV['GITHUB_FEED_TOKEN'] || ""

# Modify the feed parameters here
Feeds = [
  {
    name: "devforum-posts",
    url: "https://forum.revolutionarygamesstudio.com/posts.rss",
    maxItems: 10,
  },
  if !GithubFeedToken.empty?
    {
      name: "github-revolutionarygames",
      url: "https://github.com/organizations/Revolutionary-Games/" +
      "revolutionary-bot.private.atom?token=#{GithubFeedToken}",
      maxItems: 15,
    }
  end,
  {
    name: "community-announcements",
    url: "https://community.revolutionarygamesstudio.com/c/announcements.rss",
    maxItems: 1,
    maxLength: 300,
  },
  if !GithubFeedToken.empty?
    # Combined feed
    {
      name: "devforum-and-github",
      combine: ["devforum-posts", "github-revolutionarygames"],
      maxItems: 30,
    }
  end,
].select{|i| !i.nil?}

# Time to wait after parsing feeds is complete before doing again
UpdateEveryNSeconds = 900

TargetFolder = ENV['TARGET_FOLDER'] || "./html"

