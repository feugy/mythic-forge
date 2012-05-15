Item = require '../main/model/Item'
ItemType = require '../main/model/ItemType'

item = null
type = null

module.exports = 
  setUp: (end) ->
    type = new ItemType()
    type.set 'name', 'plain'
    type.setProperty 'rocks', 'integer', 100
    type.save ->
      Item.collection.drop -> end()

  'should item be created': (test) -> 
    # given a new Item
    item = new Item()
    item.set 'x', 10
    item.set 'y', -5
    item.set 'typeId', type._id

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
        test.equal -5, docs[0].get 'y'
        test.done()

  'should new item have default properties values': (test) ->
    # when creating an item of this type
    item = new Item()
    item.set 'typeId', type._id
    item.save (err)->
      # then the default value was set
      test.equal 100, item.get 'rocks'
      test.done()

  'given an Item': 
    setUp: (end) ->
      item = new Item()
      item.set 'x', 150
      item.set 'y', 300
      item.set 'typeId', type._id
      item.save ->
        end()

    'should item be removed': (test) ->
      # when removing an item
      item.remove ->

      # then it's in mongo anymore
      Item.find {}, (err, docs) ->
        test.equal docs.length, 0
        test.done()

    'should item be updated': (test) ->
      # when modifying and saving an item
      item.set 'x', -100
      item.save ->

        Item.find {}, (err, docs) ->
          # then it's the only one document
          test.equal docs.length, 1
          # then only the relevant values were modified
          test.equal -100, docs[0].get 'x'
          test.equal 300, docs[0].get 'y'
          test.done()

    'should dynamic property be modified': (test) ->
      # when modifying a dynamic property
      item.set 'rocks', 200
      item.save ->

        Item.findOne {_id: item._id}, (err, doc) ->
          # then only the relevant values were modified
          test.equal 150, doc.get 'x'
          test.equal 300, doc.get 'y'
          test.equal 200, doc.get 'rocks'
          test.done()

    'should item cannot be saved with unknown property': (test) ->
      # when saving an item with an unknown property
      item.set 'test', true
      item.save (err)->
        # then an error is raised
        test.fail 'An error must be raised when saving item with unknown property' if !err
        test.ok err?.message.indexOf('unknown property test') isnt -1
        test.done()