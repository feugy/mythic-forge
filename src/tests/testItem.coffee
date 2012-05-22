Item = require '../main/model/Item'
ItemType = require '../main/model/ItemType'
watcher = require('../main/model/ModelWatcher').get()

item = null
item2 = null
type = null

module.exports = 
  setUp: (end) ->
    type = new ItemType({name: 'plain'})
    type.setProperty 'rocks', 'integer', 100
    type.save (err, saved) ->
      throw new Error err if err?
      Item.collection.drop -> end()

  tearDown: (end) ->
    ItemType.collection.drop -> Item.collection.drop -> end()

  'should item be created': (test) -> 
    # given a new Item
    item = new Item {x: 10, y:-3, type:type}

    # then a creation event was issued
    watcher.once 'change', (operation, instance)->
      test.equal 'creation', operation
      test.ok item.equals instance

    # when saving it
    item.save (err) ->
      if err? 
        test.fail "Can't save item: #{err}"
        return test.done()

      # then it is in mongo
      Item.find {}, (err, docs) ->
        # then it's the only one document
        test.equal docs.length, 1
        # then it's values were saved
        test.equal 10, docs[0].get 'x'
        test.equal -3, docs[0].get 'y'
        test.expect 5
        test.done()

  'should new item have default properties values': (test) ->
    # when creating an item of this type
    item = new Item {type: type}
    item.save (err)->
      # then the default value was set
      test.equal 100, item.get 'rocks'
      test.done()

  'given an Item': 
    setUp: (end) ->
      item = new Item {x: 150, y: 300, type: type}
      item.save ->
        end()

    'should item be removed': (test) ->
      # then a removal event was issued
      watcher.once 'change', (operation, instance)->
        test.equal 'deletion', operation
        test.ok item.equals instance

      # when removing an item
      item.remove ->

        # then it's in mongo anymore
        Item.find {}, (err, docs) ->
          test.equal docs.length, 0
          test.expect 3
          test.done()

    'should item be updated': (test) ->
      # then a modification event was issued
      watcher.once 'change', (operation, instance)->
        test.equal 'update', operation
        test.ok item.equals instance
        test.equal -100, instance.x

      # when modifying and saving an item
      item.set 'x', -100
      item.save ->

        Item.find {}, (err, docs) ->
          # then it's the only one document
          test.equal docs.length, 1
          # then only the relevant values were modified
          test.equal -100, docs[0].get 'x'
          test.equal 300, docs[0].get 'y'
          test.expect 6
          test.done()

    'should dynamic property be modified': (test) ->
      # then a modification event was issued
      watcher.once 'change', (operation, instance)->
        test.equal 'update', operation
        test.ok item.equals instance
        test.equal 200, instance.rocks

      # when modifying a dynamic property
      item.set 'rocks', 200
      item.save ->

        Item.findOne {_id: item._id}, (err, doc) ->
          # then only the relevant values were modified
          test.equal 150, doc.get 'x'
          test.equal 300, doc.get 'y'
          test.equal 200, doc.get 'rocks'
          test.expect 6
          test.done()

    'should item cannot be saved with unknown property': (test) ->
      # when saving an item with an unknown property
      item.set 'test', true
      item.save (err)->
        # then an error is raised
        test.fail 'An error must be raised when saving item with unknown property' if !err
        test.ok err?.message.indexOf('unknown property test') isnt -1
        test.done()

  'given a type with object properties and several Items': 
    setUp: (end) ->
      type = new ItemType {name: 'river'}
      type.setProperty 'name', 'string', ''
      type.setProperty 'end', 'object', 'Item'
      type.setProperty 'affluents', 'array', 'Item'
      type.save ->
        Item.collection.drop -> 
          item = new Item {name: 'Rhône', end: null, type: type, affluents:[]}
          item.save (err, saved) ->
            throw new Error(err) if err?
            item = saved
            item2 = new Item {name: 'Durance', end: item, type: type, affluents:[]}
            item2.save (err, saved) -> 
              throw new Error(err) if err?
              item2 = saved
              item.set 'affluents', [item2]
              item.save (err) ->
                throw new Error(err) if err?
                end()

    'should id be stored for linked object': (test) ->
      # when retrieving an item
      Item.findOne {name: item2.get 'name'}, (err, doc) ->
        test.ifError err
        # then linked items are replaced by their ids
        test.ok item._id.equals doc.get('end')
        test.done();

    'should ids be stored for linked arrays': (test) ->
      # when resolving an item
      Item.findOne {name: item.get 'name'}, (err, doc) ->
        test.ifError err
        # then linked arrays are replaced by their ids
        test.equal 1, doc.get('affluents').length
        test.ok item2._id.equals doc.get('affluents')[0]
        test.done();

    'should resolve retrieves linked objects': (test) ->
      # given a unresolved item
      Item.findOne {name: item2.get 'name'}, (err, doc) ->
        test.ifError err
        # when resolving it
        doc.resolve (err, doc) ->
          test.ifError err
          # then linked items are provided
          test.ok item._id.equals doc.get('end')._id
          test.equal item.get('name'), doc.get('end').get('name')
          test.equal item.get('end'), doc.get('end').get('end')
          test.equal item.get('affluents')[0], doc.get('end').get('affluents')[0]
          test.done();

    'should resolve retrieves linked arrays': (test) ->
      # given a unresolved item
      Item.findOne {name: item.get 'name'}, (err, doc) ->
        test.ifError err
        # when resolving it
        doc.resolve (err, doc) ->
          test.ifError err
          # then linked items are provided
          test.equal 1, doc.get('affluents').length
          linked = doc.get('affluents')[0]
          test.ok item2._id.equals linked._id
          test.equal item2.get('name'), linked.get('name')
          test.equal item2.get('end'), linked.get('end')
          test.equal 0, linked.get('affluents').length
          test.done();

    'should multi-resolve retrieves all properties of all objects': (test) ->
      # given a unresolved items
      Item.where().asc('name').run (err, docs) ->
        test.ifError err
        # when resolving them
        Item.multiResolve docs, (err, docs) ->
          test.ifError err
          # then the first item has resolved links
          test.ok item._id.equals docs[0].get('end')._id
          test.equal item.get('name'), docs[0].get('end').get('name')
          test.equal item.get('end'), docs[0].get('end').get('end')
          test.equal item.get('affluents')[0], docs[0].get('end').get('affluents')[0]
          # then the second item has resolved links
          test.equal 1, docs[1].get('affluents').length
          linked = docs[1].get('affluents')[0]
          test.ok item2._id.equals linked._id
          test.equal item2.get('name'), linked.get('name')
          test.equal item2.get('end'), linked.get('end')
          test.equal 0, linked.get('affluents').length
          test.done();
