require! <[fs bluebird request]>
data = JSON.parse(fs.read-file-sync \output.json .toString!)
hash = {}
for item in data =>
  user = item.username or item.user
  if !user => console.log item
  if !(hash[user]?) => hash[user] = 0
  hash[user]++
rank = [[k,v] for k,v of hash]
rank.sort((a,b) -> a.1 - b.1)
console.log rank.join(\\n)


url = \https://slack.com/api/users.info
token = '' # enter your own token

result = []
fetch = (id) -> new bluebird (res, rej) ->
  console.log "fetch: #id"
  request {
    url: "#{url}?token=#token&user=#id"
    method: \GET
  }, (e,r,b) ->
    ret = JSON.parse(b)
    res ret

output = {}
final = ->
  fs.write-file-sync \rank.json, JSON.stringify(output)
fetchs = ->
  if !rank or !rank.length => return final!
  pair = rank.splice(0,1).0
  fetch pair.0 .then (ret) ->
    if !ret or !ret.ok or !ret.user => return fetchs!
    console.log ret.user.name, pair.1
    output[ret.user.name] = pair.1
    fetchs!
fetchs!
