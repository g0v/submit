require! <[request bluebird fs]>

# sample url
# https://slack.com/api/channels.history?token=[...your token...]
# documentation: https://api.slack.com/methods/channels.history

url = \https://slack.com/api/channels.history
token = '' # enter your own token
channel = \C02G2SXKX # general, got from https://api.slack.com/methods/channels.history/test

result = []
fetch = (time) -> new bluebird (res, rej) ->
  if time =>
    console.log "fetch: since #{new Date(time*1000).toString!}"
    time := "&latest=#time"
  else => console.log "fetch: latest"
  request {
    url: "#{url}?token=#token&channel=#channel#{if time => time else ''}"
    method: \GET
  }, (e,r,b) ->
    ret = JSON.parse(b)
    res ret

dump = -> fs.write-file-sync \output.json, JSON.stringify(result)

fetchs = (time) ->
  fetch time
    .then (ret) ->
      timestamp = Math.min.apply(null, ret.messages.map(-> parseFloat(it.ts)))
      result ++= ret.messages
      if result.length > 1000 => return dump!
      fetchs timestamp

fetchs!
