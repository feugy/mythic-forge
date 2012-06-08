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

 define [
  'backbone'
  'model/Item'
], (Backbone, Item) ->

  # Player account.
  class Player extends Backbone.Model

    # bind the Backbone attribute and the MongoDB attribute
    idAttribute: '_id'

    # Player account login.
    login: null

    # The associated character. Null if no character associated yet.
    character: null

    # Playr constructor.
    #
    # @param attributes [Object] raw attributes of the created instance.
    constructor: (attributes) ->
      super attributes 
      # Construct an Item for the corresponding character
      if attributes?.character?
        @set 'character', new Item attributes.character


    # An equality method that tests ids.
    #
    # @param other [Object] the object against which the current field is tested
    # @return true if both object have the samge ids, and false otherwise.
    equals: (other) =>
      @.id is other?.id

  return Player