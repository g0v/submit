require! <[request bluebird ./secret]>

fire-issue = (title, content) ->
  new bluebird (res,rej) ->
    # https://developer.github.com/v3/issues/#list-issues
    if !title or !content => return rej 'no content'
    request {
      url: \https://api.github.com/repos/g0v/submit/issues
      method: \POST
      headers: {
        "User-Agent": \g0vsubmit-node-request
      }
      "auth": {
        "user": "zbryikt"
        "pass": secret.github.token
        "sendImmediately": true
      },
      json: do
        title: title
        body: content
        labels: ['submit']
    }, (e,r,b) ->
      if e => return rej e
      res b.number

module.exports = {issue: fire: fire-issue}
