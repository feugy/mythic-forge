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

_ = require 'underscore'
encryptor = require 'password-hash'
conn = require './connection'
Item = require './Item'
typeFactory = require './typeFactory'
utils = require '../util/common'
logger = require('../util/logger').getLogger 'model'

# Define the schema for players
Player = typeFactory 'Player', 

  # email as login
  email: 
    type: String 
    required: true

  # provider: Google, Facebook or null for manual accounts.
  provider: 
    type: String
    default: null

  # last Connection date (timestamp), used to compute token validity
  lastConnection: Date

  # player informations
  firstName: String
  lastName: String

  # administrator status, to allow access to rheia
  isAdmin: 
    type: Boolean
    default: false

  # link to characters.
  characters:
    type: []
    default: -> [] # use a function to force instance variable

  # player's preference: plain json.
  prefs:
    type: {}
    default: -> {} # use a function to force instance variable

  # token used during authentication. 
  # **Not propagated by modelWatcher nor returned by AdminService**
  token: String

  # id of the current socket used.
  # **Not propagated by modelWatcher nor returned by AdminService**
  socketId: String

  # cookie used to access game developpment zone 
  # **Not propagated by modelWatcher nor returned by AdminService**
  cookie: String

  # password, only used for manually provided accounts
  # **Not propagated by modelWatcher nor returned by AdminService**
  password: 
    type: String
    default: null
, 
  strict: true 
  middlewares:

    # retrieve the characters corresponding to the stored ids.
    #
    # @param item [Item] the initialized item.
    # @param next [Function] function that must be called to proceed with other middleware.
    init: (next, player) ->
      return next() if player.characters.length is 0 
      # loads the character from database
      Item.find {_id: {$in: player.characters}}, (err, characters) ->
        return next(new Error "Unable to init item #{player.id}. Error while resolving its character: #{err}") if err?
        # Do the replacement, whatever we really found. Unexisting characters will be erased
        player.characters = _.map player.characters, (id) -> _.find characters, (character) -> character.id is id
        player.characters = _.without player.characters, null, undefined
        # store original value
        player.__origcharacters = player.characters.concat() or []
        next()

    # For manually provided accounts, check password existence.
    # Manages also associated characters, to only store their ids inside Mongo.
    #
    # @param next [Function] function that must be called to proceed with other middleware.
    save: (next) ->
      process = =>
        # If clear password provided, encrypt it before storing it.
        if @password?
          @password = encryptor.generate @password unless encryptor.isHashed @password

        # replace characters with their id, for storing in Mongo, without using setters.
        saveCharacters = @characters.concat()
        # Do not store string version of id.
        @_doc.characters[i] = character.id for character, i in saveCharacters when character?.id?
        next()
        # store new original value
        @__origcharacters = @_doc.characters.concat() or []
        # restore save to allow reference reuse.
        @_doc.characters = saveCharacters

      if @provider is null and !@password
        # before accepting saves without password, check that we have passord inside DB
        @constructor.findOne _id:@id, (err, player) ->
          return next new Error "Cannot check password existence in db for player #{@id}: #{err}" if err?
          return next new Error "Cannot save manually provided account without password" unless player?.get('password')?
          process()
      else 
        process()
        
# Simple utility method the test a clear password against the hashed stored one.
# 
# @param clearPassword [String] the clear tested value
# @return true if passwords matched, false otherwise
Player.methods.checkPassword = (clearPassword) ->
  encryptor.verify clearPassword, @password

# Simple utility method that removes from passed parameter attirbutes that must be kept on server
#
# @param player [Object] purged Mongoose model or plain object
# @return the purged player.
Player.statics.purge = (player) ->
  return player unless 'object' is utils.type player
  if '_doc' of player
    # Mongoose proxy
    delete player._doc.password
    delete player._doc.token 
    delete player._doc.cookie
    delete player._doc.socketId
  else 
    # plain raw object
    delete player.password
    delete player.token 
    delete player.cookie
    delete player.socketId
  player

module.exports = conn.model 'player', Player