require! <[fs moment request bluebird ./secret]>

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
  fetch-channel-from-time: (channel,time) -> new bluebird (res, rej) ~>
    if time =>
      console.log "[FETCH] #channel: from #{moment(time*1000).format('YY/MM/DD HH:mm:ss')}"
      param = "&latest=#time"
    else => console.log "[FETCH] Get Latest"
    request {
      url: "#{@url}?token=#{@token}&channel=#channel#{if param => param else ''}"
      method: \GET
    }, (e,r,b) -> if e => rej e else res JSON.parse(b)
  fetch-channel: (channel, since) ->
    urlmatcher = /([-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*))/g
    submissions = []
    messages = 0
    @state.{}channel{}[channel].time = since if since
    (res,rej) <~ new bluebird _
    (wrapper = ~>
      (ret) <~ @fetch-channel-from-time channel, @state.{}channel{}[channel].time .then
      timestamp = Math.max.apply(null, ret.messages.map(-> parseFloat(it.ts)))
      messages += ret.messages.length
      ret.messages.filter(->/#submit$|#submit /.exec(it.text)).forEach(->
        while true
          ret = urlmatcher.exec it.text
          if !ret => break
          submissions.push {text: it.text, link: ret.1}
      )
      oldtime = @state.{}channel{}[channel].time
      if !oldtime or timestamp > oldtime => @state.{}channel{}[channel].time = timestamp
      if !ret or !ret.[]messages.length or timestamp <= oldtime =>
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
        submissions ++= list
        wrapper!
    )!

(->
  state.init!
  slack.init!
  slack.fetch-channels!
)!

