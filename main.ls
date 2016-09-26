require! <[fs moment request bluebird cheerio ./secret ./overlap ./github]>

state = do
  init: ->
    @_ = JSON.parse(fs.read-file-sync \state.json .toString!)
  slack: -> if !(it?) => @_.slack else @_.slack <<< it
  save: -> fs.write-file-sync \state.json, JSON.stringify(@_)

link = do
  get-title: (url) -> new bluebird (res, rej) ->
    if !/https?:\/\//.exec(url) => url := "http://#url"
    (e,r,b) <- request { url: url, method: \GET}, _
    if e => return rej!
    $ = cheerio.load b
    res $(\title).text! or url

slack = do
  url: do
    channels-history: \https://slack.com/api/channels.history
    user-info: \https://slack.com/api/users.info
  init: ->
    @token = secret.slack.token
    @state = state.slack!
    @channels = @state.channels
  save: ->
    state.slack @state
    state.save!
  get-username: (id) -> new bluebird (res, rej) ~>
    request {
      url: "#{@url.user-info}?token=#{@token}&user=#id"
      method: \GET
    }, (e,r,b) ->
      if e => return rej e
      try
        json = JSON.parse(b)
      catch
        return rej!
      res json.{}user.name
  get-usernames: (list) ->
    promises = list.map (obj) ~> @get-username obj.userid .then -> obj.username = it
    bluebird.all(promises).then(->).catch(->)

  fetch-channel-by-time: (channel,time) -> new bluebird (res, rej) ~>
    if time =>
      console.log "[FETCH] #channel: from #{moment(time*1000).format('YY/MM/DD HH:mm:ss')}"
      param = "&latest=#time"
    else => console.log "[FETCH] Get Latest"
    request {
      url: "#{@url.channels-history}?token=#{@token}&channel=#channel#{if param => param else ''}"
      method: \GET
    }, (e,r,b) -> if e => rej e else res JSON.parse(b)
  fetch-channel: (channel, until-time, startby = 1469522443) ->
    urlmatcher = /([-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*))/g
    limit = [startby,(new Date!getTime!/1000)]
    submissions = []
    messages = 0
    (res,rej) <~ new bluebird _
    (wrapper = ~>
      slots = overlap @state.{}channel{}[channel].[]time, null, null, true
      slots = overlap slots, null, limit, false
      cslot = slots[* - 1]
      time = slots[* - 1].1

      (ret) <~ @fetch-channel-by-time channel, cslot.1 .then
      msgs = ret.messages.filter(->parseFloat(it.ts) >= cslot.0)
      if msgs.length =>
        mintime = Math.min.apply(null, msgs.map(-> parseFloat(it.ts)))
        maxtime = timestamp = Math.max.apply(null, msgs.map(-> parseFloat(it.ts)))
        maxtime = Math.max(maxtime, (until-time or 0))
      else
        mintime = cslot.0
        maxtime = cslot.1
      console.log [
        "[FETCH] #channel:"
        (if ret and msgs => msgs.length else 0)
        "messages since #{moment(cslot.1 * 1000).format('YY/MM/DD HH:mm:ss')}"
      ].join(" ")
      if maxtime < limit.1 or limit.1 == \latest => maxtime = limit.1
      if (!msgs or !msgs.length) and (mintime > limit.0 or limit.0 == \oldest) => mintime = limit.0

      messages += msgs.length
      msgs.filter(->/#submit$|#submit /.exec(it.text)).forEach(->
        while true
          ret = urlmatcher.exec it.text
          if !ret => break
          submissions.push {text: it.text, link: ret.1, userid: it.user}
      )
      slot = overlap @state.{}channel{}[channel].[]time, [mintime, maxtime], limit
      emptySlots = overlap slot, null, null, true
      emptySlots = overlap emptySlots, null, limit
      @state.{}channel{}[channel].time = slot
      if !emptySlots.length =>
        console.log "[FETCH] #channel done. #messages msgs scanned, #{submissions.length} submissions found."
        res submissions
      else wrapper!
    )!
  link-titles: (list) ->
    promises = list.map (obj) -> link.get-title obj.link .then -> obj.title = it
    bluebird.all(promises).then(->) .catch(->)

  fetch-channels: ->
    submissions = []
    channels = JSON.parse(JSON.stringify(@channels))
    (res, rej) <~ new bluebird _
    (wrapper = ~>
      if !channels.length =>
        @save!
        return res submissions
      c = channels.splice(0, 1).0
      list = []
      @fetch-channel(c)
        .then (ret) ~> 
          list := ret
          submissions := submissions ++ list
          @link-titles(list)
        .then ~> @get-usernames(list)
        .then -> wrapper!
    )!

(->
  state.init!
  slack.init!
  slack.fetch-channels!
    .then (newSubmissions = []) ->
      if fs.exists-sync \submissions.json =>
        submissions = JSON.parse(fs.read-file-sync \submissions.json .toString!)
      else submissions = []
      links = submissions.map(->it.link)
      newSubmissions = newSubmissions.filter(->links.indexOf(it.link) <0)
      console.log "#{newSubmissions.length} submissions found. firing issue..."
      fs.write-file-sync \submissions.json, JSON.stringify(submissions ++ newSubmissions)
      bluebird.all [github.issue.fire(
        ((item.title or item.link) + (if item.username => " (by #that)" else '')), item.text
      ) for item in newSubmissions]
    .then ->
      console.log "done."
)!
