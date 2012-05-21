Item = require '../main/model/Item'
ItemType = require '../main/model/ItemType'
watcher = require('../main/model/ModelWatcher').get()

item1 = null
item2 = null
item3 = null
type = null
module.exports = 
  setUp: (end) ->
    # empty items and types.
    Item.collection.drop -> ItemType.collection.drop -> end()

  'should type\'s properties be distinct': (test) ->
    # given a type with a property
    type = new ItemType({name: 'vehicule'})
    type.setProperty 'wheels', 'integer', 4
    type.save (err) ->
      if (err?)
        throw new Error err
        test.done()
      # when creating another type with distinct property
      type2 = new ItemType({name: 'animal'})
      type2.setProperty 'mammal', 'boolean', true
      type2.save (err) ->
        if (err?)
          throw new Error err
          test.done()
        # then their properties ar not mixed
        keys = Object.keys(type.get('properties'))
        keys2 = Object.keys(type2.get('properties'))
        test.equal 1, keys.length 
        test.equal 'wheels', keys[0] 
        test.equal 1, keys2.length
        test.equal 'mammal', keys2[0]
        test.done()

   'should type be created': (test) -> 
    # given a new ItemType
    type = new ItemType()
    name = 'montain'
    type.set 'name', name

    # when saving it
    type.save (err, saved) ->
      if err? 
        test.fail "Can't save type: #{err}"
        return test.done()

      # then it is in mongo
      ItemType.find {}, (err, types) ->
        # then it's the only one document
        test.equal types.length, 1
        # then it's values were saved
        test.equal name, types[0].get 'name'
        test.done()

  'given a type with a property': 
    setUp: (end) ->
      # creates a type with a property color which is a string.
      type = new ItemType()
      type.set 'name', 'river'
      type.setProperty 'color', 'string', 'blue'
      type.save (err, saved) -> 
        type = saved
        end()

    tearDown: (end) ->
      # removes the type at the end.
      ItemType.collection.drop -> Item.collection.drop -> end()

    'should type be removed': (test) ->
      # when removing an item
      type.remove ->

      # then it's in mongo anymore
      ItemType.find {}, (err, types) ->
        test.equal types.length, 0
        test.done()

    'should type properties be created': (test) ->
      # when adding a property
      type.setProperty 'depth', 'integer', 10
      type.save ->

        ItemType.find {}, (err, types) ->
          # then it's the only one document
          test.equal types.length, 1
          # then only the relevant values were modified
          test.equal 'river', types[0].get 'name'
          test.ok 'depth' of types[0].get('properties'), 'no depth in properties'
          test.equal 'integer',  types[0].get('properties').depth?.type
          test.equal 10, types[0].get('properties').depth?.def
          test.done()

    'should type properties be updated': (test) ->
      test.ok 'color' of type.get('properties'), 'no color in properties'
      test.equal 'string',  type.get('properties').color?.type
      test.equal 'blue',  type.get('properties').color?.def

      # when updating a property 
      type.setProperty 'color', 'integer', 10
      type.save (err, saved) ->
        # then the property was updated
        test.equal 'integer',  saved.get('properties').color?.type
        test.equal 10,  saved.get('properties').color?.def
        test.done()

    'should type properties be removed': (test) ->
      # when removing a property
      type.unsetProperty 'color'
      type.save (err, saved) ->
        if err? 
          test.fail "Can't save item: #{err}"
          return test.done()

        # then the property was removed
        test.ok not ('color' of saved.get('properties')), 'color still in properties'
        test.done()

    'should unknown type properties fail on remove': (test) ->
      try 
        # when removing an unknown property
        type.unsetProperty 'unknown'
        test.fail 'Error must be raised when removing unknwown property'
      catch err
        # then an error is thrown
        test.equal 'Unknown property unknown for item type river', err?.message
      test.done()

  'given a type and some items': 
    setUp: (end) ->
      # creates a type with a string property 'color' and an array property 'affluents'.
      type = new ItemType {name: 'river'}
      type.setProperty 'color', 'string', 'blue'
      type.setProperty 'affluents', 'array', 'Item'
      type.save (err, saved) -> 
        throw new Error(err) if err?
        type = saved
        # creates three items of this type.
        item1 = new Item {type: type, affluents: []}
        item1.save (err) ->
          throw new Error(err) if err?
          item2 = new Item {type: type, affluents: []}
          item2.save (err) ->
            throw new Error(err) if err?
            item3 = new Item {type: type, affluents: []}
            item3.save (err) -> end()

    'should existing items be updated when setting a type property': (test) ->
      updates = []
      # then a modification event was issued
      watcher.on 'updated', (updated)->
        updates.push updated._id+''
        test.equal 30, updated.depth

      # when setting a property to a type
      defaultDepth = 30
      type.setProperty 'depth', 'integer', defaultDepth
      type.save (err) -> 
        block = ->
          Item.find {type: type._id}, (err, items) ->
            for item in items
              test.equal defaultDepth, item.get 'depth'
              test.ok item._id+'' in updates
            test.done()
        setTimeout block, 50

    'should existing items be updated when removing a type property': (test) ->
      updates = []
      # then a modification event was issued
      watcher.on 'updated', (updated)->
        updates.push updated._id+''
        test.ok updated.color is undefined

      # when setting a property to a type
      defaultDepth = 30
      type.unsetProperty 'color'
      type.save (err) -> 
        block = ->
          Item.find {type: type._id}, (err, items) ->
            for item in items
              test.ok undefined is item.get('color'), 'color still present'
              test.ok item._id+'' in updates
            test.done()
        setTimeout block, 50