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
logger = require('../logger').getLogger 'model'

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

  # password, only used for manually provided accounts
  password: 
    type: String
    default: null

  # last Connection date (timestamp), used to compute token validity
  lastConnection: Number

  # player informations
  firstName: String
  lastName: String

  # administrator status, to allow access to rheia
  isAdmin: 
    type: Boolean
    default: false

  # token used during authentication
  token: String

  # cookie used to access game developpment zone
  cookie: String

  # link to characters.
  characters:
    type: []
    default: -> [] # use a function to force instance variable
, 
  strict: true 
  noDesc: true
  noName: true

# Simple utility method the test a clear password against the hashed stored one.
# 
# @param clearPassword [String] the clear tested value
# @return true if passwords matched, false otherwise
Player.methods.checkPassword = (clearPassword) ->
  encryptor.verify clearPassword, @password

# Pre-init middleware: retrieve the characters corresponding to the stored ids.
#
# @param item [Item] the initialized item.
# @param next [Function] function that must be called to proceed with other middleware.
Player.pre 'init', (next, player) ->
  return next() if player.characters.length is 0 
  # loads the character from database
  Item.find {_id: {$in: player.characters}}, (err, characters) ->
    return next(new Error "Unable to init item #{player._id}. Error while resolving its character: #{err}") if err?
    return next(new Error "Unable to init item #{player._id} because there is no item with id #{player.character}") unless characters.length is player.characters.length
    # Do the replacement.
    player.characters = characters
    next()

# Pre-save middleware: for manually provided accounts, check password existence.
# Manages also associated characters, to only store their ids inside Mongo.
#
# @param next [Function] function that must be called to proceed with other middleware.
Player.pre 'save', (next) ->
  return next new Error "Cannot save manually provided account without password" if @provider is null and !@password

  # If clear password provided, encrypt it before storing it.
  if @password?
    @password = encryptor.generate @password unless encryptor.isHashed @password

  # replace characters with their id, for storing in Mongo, without using setters.
  saveCharacters = @characters
  @_doc.characters[i] = character._id for character, i in saveCharacters
  next()
  # restore save to allow reference reuse.
  @_doc.characters = saveCharacters

module.exports = conn.model 'player', Player