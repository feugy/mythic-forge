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


fs = require 'fs'
path = require 'path'
ItemType = require '../src/model/ItemType'
FieldType = require '../src/model/FieldType'
assert = require('chai').assert
service = require('../src/service/ImagesService').get()
testUtils = require './utils/testUtils'

imagesPath = require('../src/utils').confKey 'images.store'

iType = null
fType = null

describe 'ImagesService tests', -> 

  describe 'given a item type, a field type and no image store', ->
    beforeEach (done) ->
      # removes any types and clean image folder
      ItemType.collection.drop -> FieldType.collection.drop -> testUtils.cleanFolder imagesPath, ->
        # creates an item type
        new ItemType().save (err, saved) -> 
          throw new Error err if err?
          iType = saved
          # creates an field type
          new FieldType().save (err, saved) -> 
            throw new Error err if err?
            fType = saved
            done()

    it 'should new type image be saved for item type', (done) ->
      # given an image
      fs.readFile './hyperion/test/fixtures/image1.png', (err, data) ->
        throw new Error err if err?
        # when saving the type image
        service.uploadImage 'ItemType', iType._id, 'png', data.toString('base64'), (err, saved) ->
          # then no error found
          assert.ok err is null, "unexpected error '#{err}'"
          # then the description image is updated in model
          assert.equal saved.descImage, "#{iType._id}-type.png"
          # then the file exists and is equal to the original file
          file = path.join imagesPath, saved.descImage
          assert.ok fs.existsSync file
          assert.equal fs.readFileSync(file).toString(), data.toString()
          done()

    it 'should new type image be saved for field type', (done) ->
      # given an image
      fs.readFile './hyperion/test/fixtures/image1.png', (err, data) ->
        throw new Error err if err?
        # when saving the type image
        service.uploadImage 'FieldType', fType._id, 'png', data.toString('base64'), (err, saved) ->
          # then no error found
          assert.ok err is null, "unexpected error '#{err}'"
          # then the description image is updated in model
          assert.equal saved.descImage, "#{fType._id}-type.png"
          # then the file exists and is equal to the original file
          file = path.join imagesPath, saved.descImage
          assert.ok fs.existsSync file
          assert.equal fs.readFileSync(file).toString(), data.toString()
          done()

    it 'should new instance image be saved for item type', (done) ->
      # given an image
      fs.readFile './hyperion/test/fixtures/image1.png', (err, data) ->
        throw new Error err if err?
        idx = 0
        # when saving the instance image 2
        service.uploadImage 'ItemType', iType._id, 'png', data.toString('base64'), idx, (err, saved) ->
          # then no error found
          assert.ok err is null, "unexpected error '#{err}'"
          # then the description image is updated in model
          images = saved.images[idx]
          assert.equal images?.file, "#{iType._id}-#{idx}.png"
          assert.equal images?.width, 0
          assert.equal images?.height, 0
          # then the file exists and is equal to the original file
          file = path.join imagesPath, images?.file
          assert.ok fs.existsSync file
          assert.equal fs.readFileSync(file).toString(), data.toString()
          done()

    it 'should new instance image be saved for field type', (done) ->
      # given an image
      fs.readFile './hyperion/test/fixtures/image1.png', (err, data) ->
        throw new Error err if err?
        idx = 0
        # when saving the instance image 2
        service.uploadImage 'FieldType', fType._id, 'png', data.toString('base64'), idx, (err, saved) ->
          # then no error found
          assert.ok err is null, "unexpected error '#{err}'"
          # then the description image is updated in model
          assert.equal saved.images[idx], "#{fType._id}-#{idx}.png"
          # then the file exists and is equal to the original file
          file = path.join imagesPath, saved.images[idx]
          assert.ok fs.existsSync file
          assert.equal fs.readFileSync(file).toString(), data.toString()
          done()

    it 'should all images deleted when removing item type', (done) ->
      fs.readFile './hyperion/test/fixtures/image1.png', (err, data) ->
        throw new Error err if err?
        # given an arbitraty image inside the folder
        fs.writeFile path.join(imagesPath, '123-0.png'), data, (err) ->
          throw new Error err if err?
          # given an instance image
          service.uploadImage 'ItemType', iType._id, 'png', data.toString('base64'), (err, saved) ->
            throw new Error err if err?
            # given an instance image
            service.uploadImage 'ItemType', iType._id, 'png', data.toString('base64'), 0, (err, saved) ->
              throw new Error err if err?
              assert.equal saved.descImage, "#{iType._id}-type.png"
              images = saved.images[0]
              assert.equal images?.file, "#{iType._id}-0.png"
              # when removing the type
              iType.remove (err) ->
                # wait a while for files to be deleted
                setTimeout ->
                  fs.readdir imagesPath, (err, content) ->
                    throw err if err?
                    assert.equal content.length, 1
                    # then only the arbitraty image is still in image path
                    assert.equal content[0], '123-0.png'
                    done()
                , 50

    it 'should all images deleted when removing field type', (done) ->
      fs.readFile './hyperion/test/fixtures/image1.png', (err, data) ->
        throw new Error err if err?
        # given an arbitraty image inside the folder
        fs.writeFile path.join(imagesPath, '123-0.png'), data, (err) ->
          throw new Error err if err?
          # given an instance image
          service.uploadImage 'FieldType', fType._id, 'png', data.toString('base64'), (err, saved) ->
            throw new Error err if err?
            # given an instance image
            service.uploadImage 'FieldType', fType._id, 'png', data.toString('base64'), 0, (err, saved) ->
              throw new Error err if err?
              assert.equal saved.descImage, "#{fType._id}-type.png"
              assert.equal saved.images[0], "#{fType._id}-0.png"
              # when removing the type
              fType.remove (err) ->
                # wait a while for files to be deleted
                setTimeout ->
                  fs.readdir imagesPath, (err, content) ->
                    throw err if err?
                    assert.equal content.length, 1
                    # then only the arbitraty image is still in image path
                    assert.equal content[0], '123-0.png'
                    done()
                , 50

  describe 'given a type and its type image', ->

    beforeEach (done) ->
      # removes any types and clean image folder
      ItemType.collection.drop -> testUtils.cleanFolder imagesPath, ->
        # creates a type
        new ItemType().save (err, saved) -> 
          throw new Error err if err?
          iType = saved
          # saves a type image for it
          fs.readFile './hyperion/test/fixtures/image1.png', (err, data) ->
            throw new Error err if err?
            service.uploadImage 'ItemType', iType._id, 'png', data.toString('base64'), (err, saved) ->
              throw new Error err if err?
              iType = saved
              # saves a instance image for it
              service.uploadImage 'ItemType', iType._id, 'png', data.toString('base64'), 0, (err, saved) ->
                throw new Error err if err?
                iType = saved
                done()

    it 'should existing type image be changed', (done) ->
      # given a new image
      fs.readFile './hyperion/test/fixtures/image2.png', (err, data) ->
        throw new Error err if err?
        # when saving the type image
        service.uploadImage 'ItemType', iType._id, 'png', data.toString('base64'), (err, saved) ->
          # then no error found
          assert.ok err is null, "unexpected error '#{err}'"
          # then the description image is updated in model
          assert.equal saved.descImage, "#{iType._id}-type.png"
          # then the file exists and is equal to the original file
          file = path.join imagesPath, saved.descImage
          assert.ok fs.existsSync file
          assert.equal fs.readFileSync(file).toString(), data.toString()
          done()

    it 'should existing type image be removed', (done) ->
      file = path.join imagesPath, iType.descImage
      # when removing the type image
      service.removeImage 'ItemType', iType._id, (err, saved) ->
        # then no error found
        assert.ok err is null, "unexpected error '#{err}'"
        # then the type image is updated in model
        assert.equal saved.descImage, null
        # then the file do not exists anymore
        assert.ok !(fs.existsSync(file))
        done()

    it 'should existing instance image be changed', (done) ->
      idx = 0
      # given a new image
      fs.readFile './hyperion/test/fixtures/image2.png', (err, data) ->
        throw new Error err if err?
        # when saving the type image
        service.uploadImage 'ItemType', iType._id, 'png', data.toString('base64'), idx, (err, saved) ->
          # then no error found
          assert.ok err is null, "unexpected error '#{err}'"
          # then the description image is updated in model
          images = saved.images[idx]
          assert.equal images?.file, "#{iType._id}-#{idx}.png"
          assert.equal images?.width, 0
          assert.equal images?.height, 0
          # then the file exists and is equal to the original file
          file = path.join imagesPath, images?.file
          assert.ok fs.existsSync file
          assert.equal fs.readFileSync(file).toString(), data.toString()
          done()

    it 'should existing instance image be removed', (done) ->
      idx = 0
      file = path.join imagesPath, iType.images[idx].file
      # when removing the first instance image
      service.removeImage 'ItemType', iType._id, idx, (err, saved) ->
        # then no error found
        assert.ok err is null, "unexpected error '#{err}'"
        # then the instance image is updated in model
        assert.equal saved.images[idx], undefined
        # then the file do not exists anymore
        assert.ok !(fs.existsSync(file))
        done()

    it 'should existing instance image be set to null', (done) ->
      # given another image
      fs.readFile './hyperion/test/fixtures/image1.png', (err, data) ->
        throw new Error err if err?
        # given it saved as second instance image
        service.uploadImage 'ItemType', iType._id, 'png', data.toString('base64'), 1, (err, saved) ->
          file = path.join imagesPath, iType.images[0].file
          # when removing the first instance image
          service.removeImage 'ItemType', iType._id, 0, (err, saved) ->
            # then no error found
            assert.ok err is null, "unexpected error '#{err}'"
            # then the instance image is updated in model
            assert.equal saved.images.length, 2
            assert.equal saved.images[0]?.file, null
            # then the file do not exists anymore
            assert.ok !(fs.existsSync(file))
            done()