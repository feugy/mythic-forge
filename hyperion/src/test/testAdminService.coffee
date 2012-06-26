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

ItemType = require '../main/model/ItemType'
service = require('../main/service/AdminService').get()
assert = require('chai').assert
     
itemTypes = []

describe 'AdminService tests', -> 

  before (done) ->
    ItemType.collection.drop -> 
      # creates fixtures
      created = [
        {clazz: ItemType, args: {name: 'type 1'}, store: itemTypes},
        {clazz: ItemType, args: {name: 'type 2'}, store: itemTypes}
      ]
      create = (def) ->
        return done() unless def?
        new def.clazz(def.args).save (err, saved) ->
          throw new Error err if err?
          def.store.push saved
          create created.pop()

      create created.pop()

  it 'should list fails on unallowed model', (done) ->
    # when listing unallowed model
    service.list 'toto', (err, modelName, list) ->
      # then an error occured
      assert.equal err, 'The toto model can\'t be listed'
      assert.equal modelName, 'toto'
      done()

  it 'should list returns item types', (done) ->
    # when listing all item types
    service.list 'ItemType', (err, modelName, list) ->
      throw new Error "Can't list itemTypes: #{err}" if err?
      # then the two created types are retrieved
      assert.equal 2, list.length
      assert.equal modelName, 'ItemType'
      assert.ok itemTypes[0].equals list[0]
      assert.ok itemTypes[1].equals list[1]
      done()