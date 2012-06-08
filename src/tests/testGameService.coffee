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

Item = require '../main/model/Item'
ItemType = require '../main/model/ItemType'
Map = require '../main/model/Map'
Field = require '../main/model/Field'
service = require('../main/service/GameService').get()
     
type = null
item1 = null
item2 = null
item3 = null
map = null
field1 = null
field2 = null

module.exports = 

  setUp: (end) ->
    # cleans ItemTypes and Items
    ItemType.collection.drop -> Item.collection.drop -> Map.collection.drop -> Field.collection.drop ->
      # given a map
      new Map({name: 'test-game'}).save (err, saved) ->
        throw new Error err if err?
        map = saved
        # given an item type
        type = new ItemType {name: 'character'}
        type.setProperty 'name', 'string', ''
        type.setProperty 'health', 'integer', 10
        type.save (err, saved) ->
          throw new Error err if err?
          type = saved
          new Item({map: map, type: type, name: 'Jack', x:0, y:0}).save (err, saved) ->
            throw new Error err if err?
            item1 = saved
            new Item({map: map, type: type, name: 'John', x:10, y:10}).save (err, saved) ->
              throw new Error err if err?
              item2 = saved
              new Item({map: map, type: type, name: 'Peter'}).save (err, saved) ->
                throw new Error err if err?
                item3 = saved
                new Field({map: map, x:5, y:3}).save (err, saved) ->
                  throw new Error err if err?
                  field1 = saved
                  new Field({map: map, x:-2, y:-10}).save (err, saved) ->
                    throw new Error err if err?
                    field2 = saved
                    end()

  'should consultMap returned only relevant items': (test) ->
    # when retrieving items within coordinate -5:-5 and 5:5
    service.consultMap map._id, -5, -5, 5, 5, (err, items, fields) ->
      throw new Error "Can't consultMap: #{err}" if err?
      # then only item1 is returned
      test.equal 1, items.length
      test.ok item1.equals items[0]
      # then only field1 returned
      test.equal 1, fields.length
      test.ok field1.equals fields[0]
      test.done()
        
  'should consultMap returned nothing if no item found': (test) ->
    # when retrieving items within coordinate -1:-1 and -5:-5
    service.consultMap map._id, -1, -1, -5, -5, (err, items, fields) ->
      throw new Error "Can't consultMap: #{err}" if err?
      # then no items returned
      test.equal 0, items.length
      # then no fields returned
      test.equal 0, fields.length
      test.done()
