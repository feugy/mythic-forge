Item = require '../model/Item'
ruleService = require('./RuleService').get()
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

  # @todo just a simple test
  greetings: (name, callback) =>
    callback null, "Hi #{name} ! My name is Joe"

_instance = undefined
class GameService
  @get: ->
    _instance ?= new _GameService()

module.exports = GameService