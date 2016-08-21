add = (ranges,r = null, limit = null,inverse = false) ->
  list = []
  if r => ranges.push r
  for item in ranges =>
    list.push [item.0, 0]
    list.push [item.1, 1]
  list.sort (a,b) -> a.0 - b.0
  for i from 0 til list.length => if list[i].0 < 0 => list[i].0 = 0
  if Array.isArray limit => 
    for i from 0 til list.length =>
      if list[i].0 <= limit.0 or list[i].0 == 'oldest' => list[i].0 = limit.0
      if list[i].0 >= limit.1 or list[i].0 == 'latest' => list[i].0 = limit.1
  range = [0,0,0,0]  # start / end / counting / count
  ret = []
  flag = if inverse => [1,0] else [0,1]
  if inverse =>
    list = (
      [['oldest', 1]] ++ 
      list ++
      [['latest', 0]]
    )
  for p in list =>
    if range.2 == 0 and p.1 == flag.0 =>
      range.0 = p.0
      range.2 = 1
    if range.2 => range.3 += (if p.1 == flag.1 => -1 else 1)
    if range.2 and !range.3 =>
      range.1 = p.0
      range.2 = 0
      ret.push [range.0, range.1]
  if range.2 => ret.push [limit.1, 'latest']
  ret = ret.filter -> it.0 != it.1
  return ret

assert = (a,b) -> JSON.stringify(a) == JSON.stringify(b)
testcases = ->
  ret = add [[0,1],[3,6],[9,10]],[9,22]
  console.log assert(ret, [[0,1],[3,6],[9,22]])
  ret = add ret, null, [4,11], true
  console.log assert(ret, [['oldest',4],[6,9],[11,'latest']])
  ret = add [[4,8]], null, [-4,101], true
  console.log assert(ret, [['oldest',4],[8,'latest']])
  ret = add [[4,8]], null, [3,9], true
  console.log assert(ret, [['oldest',4],[8,'latest']])
  ret = add [], null, null, true
  console.log assert(ret, [['oldest','latest']])
  ret = add [], null, [[0,100]], true
  console.log assert(ret, [['oldest','latest']])

module.exports = add
