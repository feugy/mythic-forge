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
###
'use strict'

ItemType = require '../model/ItemType'
logger = require('../logger').getLogger 'service'

# The AdminService export administration features.
# It's a singleton class. The unic instance is retrieved by the `get()` method.
#
class _AdminService

  # The list method retrieve all instances of a given model
  #
  # @param modelName [String] class name of the listed models
  # @param callback [Function] end callback, invoked with two arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback modelName [String] reminds the listed model class name
  # @option callback models [Array] list (may be empty) of retrieved models
  #
  list: (modelName, callback) =>
    return callback "The #{modelName} model can't be listed", modelName unless modelName in ['ItemType']
    switch modelName
      when 'ItemType' then ItemType.find (err, result) -> callback err, modelName, result

_instance = undefined
class AdminService
  @get: ->
    _instance ?= new _AdminService()

module.exports = AdminService