require! <[request bluebird fs cheerio]>

get-title = (url) -> new bluebird (res, rej) ->
  if !/https?:\/\//.exec(url) => url := "http://#url"
  console.log url
  (e,r,b) <- request { url: url, method: \GET}, _
  if e => return rej!
  $ = cheerio.load b
  res $(\title).text! or url

# sample usage
# get-title \zbryikt.github.io
#   .then -> it
#   .catch -> console.log \xxx
