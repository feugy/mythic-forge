Item = require '../model/Item'
logger = require('../logger').getLogger 'service'

# The GameService allow all operations needed by the game interface.
# It's a singleton class. The unic instance is retrieved by the `get()` method.
#
class _GameService

  # Retrieve all items that belongs to a map within given coordinates.
  #
  # @param lowX [Number] abscissa lower bound (included)
  # @param lowY [Number] ordinate lower bound (included)
  # @param upX [Number] abscissa upper bound (included)
  # @param upY [Number] ordinate upper bound (included)  
  # @param callback [Function] callback executed when items where retrieved. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback items [Array<Item>] list of retrieved items. May be empty.
  consultMap: (lowX, lowY, upX, upY, callback) =>
    Item.where('x').gte(lowX)
      .where('x').lte(upX)
      .where('y').gte(lowY)
      .where('y').lte(upY)
      .run callback

  # @todo just a simple test
  greetings: (name, callback) =>
    callback null, "Hi #{name} ! My name is Joe"

class GameService
  _instance = undefined
  @get: ->
    _instance ?= new _GameService()

module.exports = GameService