# Modify the feed parameters here
Feeds = [
  {
    name: "devforum-posts",
    url: "https://forum.revolutionarygamesstudio.com/posts.rss",
    maxItems: 10,
  },
  {
    name: "website-announcements",
    url: "https://community.revolutionarygamesstudio.com/c/announcements.rss",
    maxItems: 3,
  },
]

# Time to wait after parsing feeds is complete before doing again
UpdateEveryNSeconds = 900

TargetFolder = if ENV['TARGET_FOLDER']
                 ENV['TARGET_FOLDER']
               else
                 "./html"
               end
