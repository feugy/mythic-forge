Rule = require '../main/model/Rule'

module.exports = new (class Move extends Rule
  constructor: ->
    @name= 'move'

  canExecute: (actor, target, callback) =>
    # Do not apply on items
    callback null, false if target.type?
    tX = target.get('x').valueOf()
    tY = target.get('y').valueOf()
    x = actor.get('x').valueOf()
    y = actor.get('y').valueOf()
    
    return callback null, false if tX is x and tY is y
    if y % 2 is 1
      callback null, (tX >= x and tX <= x+1 and tY >= y-1 and tY <= y+1) or (tX == x-1 and tY == y)
    else 
      callback null, (tX >= x-1 and tX <= x and tY >= y-1 and tY <= y+1) or (tX == x+1 and tY == y)

  execute: (actor, target, callback) =>
    # move the actor on the target
    actor.set 'x', target.get 'x'
    actor.set 'y', target.get 'y'
    callback null

)()