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


fs = require 'fs'
path = require 'path'
ItemType = require '../main/model/ItemType'
assert = require('chai').assert
service = require('../main/service/ImagesService').get()
testUtils = require './utils/testUtils'

imagesPath = require('../main/utils').confKey 'images.store'

type = null

describe 'ImagesService tests', -> 

  describe 'given a type and no image store', ->
    beforeEach (done) ->
      # removes any types and clean image folder
      ItemType.collection.drop -> testUtils.cleanFolder imagesPath, ->
        # creates a type
        new ItemType().save (err, saved) -> 
          throw new Error err if err?
          type = saved
          done()

    it 'should new type image be saved', (done) ->
      # given an image
      fs.readFile './hyperion/src/test/fixtures/image1.png', (err, data) ->
        throw new Error err if err?
        # when saving the type image
        service.save type, {ext:'png', width:50, height:50}, data, (err, saved) ->
          # then no error found
          assert.ok err is null, "unexpected error '#{err}'"
          # then the description image is updated in model
          assert.equal saved.get('descImage'), "#{type._id}-type.png"
          # then the file exists and is equal to the original file
          file = path.join imagesPath, saved.get('descImage')
          assert.ok fs.existsSync file
          assert.equal fs.readFileSync(file).toString(), data.toString()
          done()

    it 'should new instance image be saved', (done) ->
      # given an image
      fs.readFile './hyperion/src/test/fixtures/image1.png', (err, data) ->
        throw new Error err if err?
        idx = 2
        # when saving the instance image 2
        service.save type, {ext:'png', width:50, height:75}, data, idx, (err, saved) ->
          # then no error found
          assert.ok err is null, "unexpected error '#{err}'"
          # then the description image is updated in model
          images = saved.get('images')[idx]
          assert.equal images?.file, "#{type._id}-#{idx}.png"
          assert.equal images?.width, 50
          assert.equal images?.height, 75
          # then the file exists and is equal to the original file
          file = path.join imagesPath, images?.file
          assert.ok fs.existsSync file
          assert.equal fs.readFileSync(file).toString(), data.toString()
          done()

  describe 'given a type and its type image', ->

    beforeEach (done) ->
      # removes any types and clean image folder
      ItemType.collection.drop -> testUtils.cleanFolder imagesPath, ->
        # creates a type
        new ItemType().save (err, saved) -> 
          throw new Error err if err?
          type = saved
          # saves a type image for it
          fs.readFile './hyperion/src/test/fixtures/image1.png', (err, data) ->
            throw new Error err if err?
            service.save type, {ext:'png', width:50, height:50}, data, (err, saved) ->
              throw new Error err if err?
              type = saved
              # saves a instance image for it
              service.save type, {ext:'png', width:50, height:50}, data, 2, (err, saved) ->
                throw new Error err if err?
                type = saved
                done()

    it 'should existing type image be changed', (done) ->
      # given a new image
      fs.readFile './hyperion/src/test/fixtures/image2.png', (err, data) ->
        throw new Error err if err?
        # when saving the type image
        service.save type, {ext:'png', width:50, height:50}, data, (err, saved) ->
          # then no error found
          assert.ok err is null, "unexpected error '#{err}'"
          # then the description image is updated in model
          assert.equal saved.get('descImage'), "#{type._id}-type.png"
          # then the file exists and is equal to the original file
          file = path.join imagesPath, saved.get('descImage')
          assert.ok fs.existsSync file
          assert.equal fs.readFileSync(file).toString(), data.toString()
          done()

    it 'should existing type image be removed', (done) ->
      file = path.join imagesPath, type.get 'descImage'
      # when removing the tyê image
      service.remove type, (err, saved) ->
        # then no error found
        assert.ok err is null, "unexpected error '#{err}'"
        # then the type image is updated in model
        assert.equal saved.get('descImage'), null
        # then the file do not exists anymore
        assert.ok !(fs.existsSync(file))
        done()

    it 'should existing instance image be changed', (done) ->
      idx = 2
      # given a new image
      fs.readFile './hyperion/src/test/fixtures/image2.png', (err, data) ->
        throw new Error err if err?
        # when saving the type image
        service.save type, {ext:'png', width:100, height:150}, data, idx, (err, saved) ->
          # then no error found
          assert.ok err is null, "unexpected error '#{err}'"
          # then the description image is updated in model
          images = saved.get('images')[idx]
          assert.equal images?.file, "#{type._id}-#{idx}.png"
          assert.equal images?.width, 100
          assert.equal images?.height, 150
          # then the file exists and is equal to the original file
          file = path.join imagesPath, images?.file
          assert.ok fs.existsSync file
          assert.equal fs.readFileSync(file).toString(), data.toString()
          done()

    it 'should existing instance image be removed', (done) ->
      idx = 2
      file = path.join imagesPath, type.get('images')[idx].file
      # when removing the tyê image
      service.remove type, idx, (err, saved) ->
        # then no error found
        assert.ok err is null, "unexpected error '#{err}'"
        # then the instance image is updated in model
        assert.equal saved.get('images')[idx], undefined
        # then the file do not exists anymore
        assert.ok !(fs.existsSync(file))
        done()