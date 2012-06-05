Player = require '../model/Player'
Item = require '../model/Item'
logger = require('../logger').getLogger 'service'

# The PlayerService performs registration and authentication of players.
# It's a singleton class. The unic instance is retrieved by the `get()` method.
#
class _PlayerService

  # Create a new player account. Check the login unicity before creation. 
  #
  # @param login [String] the player login
  # @param callback [Function] callback executed when player was created. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback player [Player] the created player.
  register: (login, callback) =>
    logger.debug "Create new player with login: #{login}"
    # check login unicity
    @getByLogin login, (err, player) ->
      return callback "Can't check login unicity: #{err}", null if err?
      return callback "Login #{login} is already used", null if player?
      new Player({login: login}).save (err, newPlayer) ->
        callback err, newPlayer

  # Retrieve a player by it's login, with its character resolved.
  #
  # @param login [String] the player login
  # @param callback [Function] callback executed when player was retrieved. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback player [Player] the concerned player. May be null.
  getByLogin: (login, callback) =>
    logger.debug "consult player by login: #{login}"
    Player.findOne {login: login}, (err, player) =>
      return callback err, null if err?
      if player?.get('character')?
        logger.debug 'resolves its character'
        # resolve the character
        player.get('character').resolve (err) =>
          return callback err, null if err?
          callback null, player
      else 
        callback null, player

_instance = undefined
class PlayerService
  @get: ->
    _instance ?= new _PlayerService()

module.exports = PlayerService