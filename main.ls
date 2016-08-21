require! <[fs moment request bluebird ./secret ./overlap ./github]>

state = do
  init: ->
    @_ = JSON.parse(fs.read-file-sync \state.json .toString!)
  slack: -> if !(it?) => @_.slack else @_.slack <<< it
  save: -> fs.write-file-sync \state.json, JSON.stringify(@_)

slack = do
  init: ->
    @url = \https://slack.com/api/channels.history
    @token = secret.slack.token
    @state = state.slack!
    @channels = @state.channels
  save: ->
    state.slack @state
    state.save!
  fetch-channel-by-time: (channel,time) -> new bluebird (res, rej) ~>
    if time =>
      console.log "[FETCH] #channel: from #{moment(time*1000).format('YY/MM/DD HH:mm:ss')}"
      param = "&latest=#time"
    else => console.log "[FETCH] Get Latest"
    request {
      url: "#{@url}?token=#{@token}&channel=#channel#{if param => param else ''}"
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
          submissions.push {text: it.text, link: ret.1}
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
  fetch-channels: ->
    submissions = []
    channels = JSON.parse(JSON.stringify(@channels))
    (res, rej) <~ new bluebird _
    (wrapper = ~>
      if !channels.length =>
        @save!
        return res submissions
      c = channels.splice(0, 1).0
      @fetch-channel c .then (list) ~>
        submissions := submissions ++ list
        wrapper!
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
      console.log "#{newSubmissions} submissions found. firing issue..."
      fs.write-file-sync \submissions.json, JSON.stringify(submissions ++ newSubmissions)
      bluebird.all [github.issue.fire(item.link, item.text) for item in newSubmissions]
    .then ->
      console.log "done."
)!

