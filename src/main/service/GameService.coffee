Item = require '../model/Item'
ItemType = require '../model/ItemType'
Executable = require '../model/Executable'
ruleService = require('./RuleService').get()
logger = require('../logger').getLogger 'service'

# The GameService allow all operations needed by the game interface.
# It's a singleton class. The unic instance is retrieved by the `get()` method.
#
class _GameService

  # Retrieve Item types by their ids
  #
  # @param ids [Array<String>] array of ids
  # @param callback [Function] callback executed when types where retrieved. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback types [Array<ItemType>] list of retrieved types. May be empty.
  getTypes: (ids, callback) =>
    logger.debug "Consult types with ids: #{ids}"
    ItemType.find {_id: {$in: ids}}, callback

  # Retrieve Items by their ids. Each item links are resolved.
  #
  # @param ids [Array<String>] array of ids
  # @param callback [Function] callback executed when items where retrieved. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback types [Array<Item>] list of retrieved items. May be empty.
  getItems: (ids, callback) =>
    logger.debug "Consult items with ids: #{ids}"
    Item.find {_id: {$in: ids}}, (err, items) ->
      return callback err, null if err?
      Item.multiResolve items, callback

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
    logger.debug "Consult map between #{lowX}:#{lowY} and #{upX}:#{upY}"
    Item.where('x').gte(lowX)
      .where('x').lte(upX)
      .where('y').gte(lowY)
      .where('y').lte(upY)
      .run callback

  # Trigger the rule engine resolution
  # 
  # @see {RuleService.resolve}
  resolveRules: () =>
    logger.debug 'Trigger rules resolution'
    ruleService.resolve.apply ruleService, arguments

  # Trigger the rule engine execution
  # 
  # @see {RuleService.execute}
  executeRule: () =>
    logger.debug 'Trigger rules execution'
    ruleService.execute.apply ruleService, arguments

  # Returns the executable's content to allow rule execution on client side
  #
  # @param callback [Function] callback executed when executables where retrieved. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback items [Array<Executable>] list of retrieved executables. May be empty.
  getExecutables: (callback) =>
    logger.debug 'Consult all executables'
    Executable.find callback

_instance = undefined
class GameService
  @get: ->
    _instance ?= new _GameService()

module.exports = GameService