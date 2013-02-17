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

Item = require '../hyperion/src/model/Item'
ItemType = require '../hyperion/src/model/ItemType'
Map = require '../hyperion/src/model/Map'
Field = require '../hyperion/src/model/Field'
FieldType = require '../hyperion/src/model/FieldType'
utils = require '../hyperion/src/util/common'
testUtils = require './utils/testUtils'
Executable = require '../hyperion/src/model/Executable'
service = require('../hyperion/src/service/GameService').get()
assert = require('chai').assert
     
type = null
item1 = null
item2 = null
item3 = null
map = null
field1 = null
field2 = null

describe 'GameService tests', -> 

  beforeEach (done) ->
    # cleans ItemTypes and Items
    testUtils.cleanFolder utils.confKey('executable.source'), (err) -> 
      return done err if err?
      Executable.resetAll true, (err) -> 
        return done err if err?
        ItemType.collection.drop -> Item.collection.drop -> Map.collection.drop -> FieldType.collection.drop -> Field.collection.drop -> Map.loadIdCache ->
          # given a map
          new Map(id: 'test-game').save (err, saved) ->
            return done err if err?
            map = saved
            # given an item type
            type = new ItemType id: 'character'
            type.setProperty 'name', 'string', ''
            type.setProperty 'health', 'integer', 10
            type.save (err, saved) ->
              return done err if err?
              type = saved
              new Item({map: map, type: type, name: 'Jack', x:0, y:0}).save (err, saved) ->
                return done err if err?
                item1 = saved
                new Item({map: map, type: type, name: 'John', x:10, y:10}).save (err, saved) ->
                  return done err if err?
                  item2 = saved
                  new Item({map: map, type: type, name: 'Peter'}).save (err, saved) ->
                    return done err if err?
                    item3 = saved
                    # given a field type
                    new FieldType(id: 'plain').save (err, saved) ->
                      return done err if err?
                      fieldType = saved
                      new Field({mapId:map.id, typeId:fieldType.id, x:5, y:3}).save (err, saved) ->
                        return done err if err?
                        field1 = saved
                        new Field({mapId:map.id, typeId:fieldType.id, x:-2, y:-10}).save (err, saved) ->
                          return done err if err?
                          field2 = saved
                          done()

  it 'should consultMap returned only relevant items', (done) ->
    # when retrieving items within coordinate -5:-5 and 5:5
    service.consultMap map.id, -5, -5, 5, 5, (err, items, fields) ->
      throw new Error "Can't consultMap: #{err}" if err?
      # then only item1 is returned
      assert.equal items.length, 1
      assert.ok item1.equals items[0]
      # then only field1 returned
      assert.equal fields.length, 1
      assert.ok field1.equals fields[0]
      done()
        
  it 'should consultMap returned nothing if no item found', (done) ->
    # when retrieving items within coordinate -1:-1 and -5:-5
    service.consultMap map.id, -1, -1, -5, -5, (err, items, fields) ->
      throw new Error "Can't consultMap: #{err}" if err?
      # then no items returned
      assert.equal items.length, 0
      # then no fields returned
      assert.equal fields.length, 0
      done()
        
  it 'should importRules returned nothing', (done) ->
    # when importing rules
    service.importRules (err, rules) ->
      throw new Error "Can't importRules: #{err}" if err?
      # then no rules were exported
      for key of rules
        assert.fail 'no rules may have been returned'
      done()