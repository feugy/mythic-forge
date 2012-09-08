###
  Copyright 2010,2011,2012 Damien Feugas
  
    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Myth is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser Public License for more details.

    You should have received a copy of the GNU Lesser Public License
    along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###
'use strict'

Player = require '../model/Player'
Item = require '../model/Item'
utils = require '../utils'
logger = require('../logger').getLogger 'service'

expiration = utils.confKey 'authentication.tokenLifeTime'

# The PlayerService performs registration and authentication of players.
# It's a singleton class. The unic instance is retrieved by the `get()` method.
#
class _PlayerService

  # Service constructor.
  # Ensure admin account existence.
  constructor: ->
    Player.findOne {email:'admin'}, (err, result) =>
      throw "Unable to check admin account existence: #{err}" if err?
      return logger.info '"admin" account already exists' if result?
      new Player(email:'admin', password: 'admin', isAdmin:true).save (err) =>
        throw "Unable to create admin account: #{err}" if err?
        logger.warn '"admin" account has been created with password "admin". Please change it immediately'

  # Create a new player account. Check the email unicity before creation. 
  #
  # @param email [String] the player email
  # @param password [String] the player password.
  # @param callback [Function] callback executed when player was created. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback player [Player] the created player.
  register: (email, password, callback) =>
    return callback 'Email is mandatory' unless email
    return callback 'Password is mandatory' unless password
    logger.info "Register new player with email: #{email}"
    # check email unicity
    @getByEmail email, (err, player) ->
      return callback "Can't check email unicity: #{err}", null if err?
      return callback "Email #{email} is already used", null if player?
      new Player({email: email, password:password}).save (err, newPlayer) ->
        logger.info "New player (#{newPlayer.id}) registered with email: #{email}"
        callback err, newPlayer

  # Authenticate a manually created account. 
  # Usable with passport-local
  #
  # @param email [String] User email
  # @param password [String] clear password value
  # @param callback [Function] callback executed when player was authenticated. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured. Will became Http error message
  # @option callback token [String] the generated access token, or false if authentication refused
  # @option callback details [Object] an error detailed object containing attributes `type` and `message`
  authenticate: (email, password, callback) =>
    logger.debug "Authenticate player with email: #{email}"
    # check user existence
    @getByEmail email, (err, player) =>
      return callback "Failed to check player existence: #{err}" if err?
      # check player existence and password correctness
      return callback null, false, {type:'error', message:'Wrong credentials'} if player is null or !player.checkPassword password
      # update the saved token and last connection date
      player.set 'token', utils.generateToken 24
      player.set 'lastConnection', new Date().getTime()
      player.save (err, newPlayer) ->
        return callback "Failed to update player: #{err}" if err?
        logger.info "Player (#{newPlayer.id}) authenticated with email: #{email}"
        callback null, newPlayer.get 'token'

  # Authenticate a Google account: if account does not exists, creates it, or returns the existing one
  # Usable with passport-google-oauth.
  #
  # @param accessToken [String] OAuth2 access token
  # @param refreshToken [String] OAuth2 refresh token
  # @param profile [Object] Google profile details.
  # @option profile emails [Array] array of user's e-mails
  # @option profile name [Object] contains givenName (first name) and familyName (last name)
  # @param callback [Function] callback executed when player was authenticated. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback token [String] the generated access token.
  authenticatedFromGoogle: (accessToken, refreshToken, profile, callback) =>
    email = profile.emails[0].value
    return callback 'No email found in profile' unless email?
    logger.debug "Authenticate Google player with email: #{email}"
    
    # check user existence
    @getByEmail email, (err, player) =>
      return callback "Failed to check player existence: #{err}" if err?
      # Create or update account
      unless player?
        logger.info "Register Google player with email: #{email}"
        player = new Player
          email: email
          provider: 'Google'
          firstName: profile.name.givenName
          lastName: profile.name.familyName

      # update the saved token and last connection date
      player.set 'token', utils.generateToken 24
      player.set 'lastConnection', new Date().getTime()
      player.save (err, newPlayer) ->
        return callback "Failed to update player: #{err}" if err?
        logger.info "Google player (#{newPlayer.id}) authenticated with email: #{email}"
        callback null, newPlayer.get 'token'

  # Retrieve a player by its email, with its characters resolved.
  #
  # @param email [String] the player email
  # @param resolve [Boolean] true to resolve character, false otherwise. True by default
  # @param callback [Function] callback executed when player was retrieved. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback player [Player] the concerned player. May be null.
  getByEmail: (email, resolve, callback) =>
    if 'function' is utils.type resolve
      callback = resolve
      resolve = true
    logger.debug "consult player by email: #{email}"
    Player.findOne {email: email}, (err, player) =>
      return callback err, null if err?
      if player? and player.get('characters').length isnt 0 and resolve
        logger.debug 'resolves its character'
        # resolve the character
        Item.multiResolve player.get('characters'), (err, instances) =>
          return callback err, null if err?
          player.set 'characters', instances
          callback null, player
      else 
        callback null, player

  # Retrieve a player by its token. 
  # If a player is found, its token is reseted to null to avoid reusing it.
  #
  # @param token [String] the concerned token
  # @param callback [Function] callback executed when player was retrieved. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback player [Player] the corresponding player. May be null.
  getByToken: (token, callback) =>
    Player.findOne {token: token}, (err, player) =>
      return callback err, null if err?
      # no player found
      return callback null, null unless player?

      # check expiration date
      if player.get('lastConnection')+expiration*1000 < new Date().getTime()
        # expired token: set it to null
        player.set 'token', null
        player.save (err, saved) =>
          return callback "Failed to reset player's expired token: #{err}" if err?
          callback "Expired token"
      else
        # change token for security reason
        player.set 'token', utils.generateToken 24
        player.save (err, saved) =>
          return callback "Failed to change player's token: #{err}" if err?
          callback null, saved

  # Disconnect a player by its email. Token will be set to null.
  #
  # @param token [String] the concerned token
  # @param callback [Function] callback executed when player was disconnected. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback player [Player] the disconnected player.
  disconnect: (email, callback) =>
    Player.findOne {email: email}, (err, player) =>
      return callback err if err?
      return callback "No player with email #{email} found" unless player?
      # set token to null
      player.set 'token', null
      player.save (err, saved) =>
        return callback "Failed to reset player's token: #{err}" if err?
        callback null, saved

_instance = undefined
class PlayerService
  @get: ->
    _instance ?= new _PlayerService()

module.exports = PlayerService