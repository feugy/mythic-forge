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
pathUtils = require 'path'
fsExtra = require 'fs-extra'
async = require 'async'
FSItem = require '../main/model/FSItem'
utils = require '../main/utils'
watcher = require('../main/model/ModelWatcher').get()
assert = require('chai').assert

root = null
awaited = false

# Simple code factorization on fs-items creation
#
# @param item [FSItem] saved item
# @param isFolder [Boolean] awaited folder status
# @param content [String|Buffer|Array] optionnal item content. true by default
# @param isNew [Boolean] optionnal distinguish creation from update. true by default
# @param done [Function] test done function.
assertFSItemSave = (item, isFolder, content, isNew, done) ->
  if 'function' is utils.type content
    done = content
    content = null
    isNew = true
  else if 'function' is utils.type isNew
    done = isNew
    isNew = true

  # then a creation event was issued
  watcher.once 'change', (operation, className, instance)->
    assert.equal className, 'FSItem'
    assert.equal operation, if isNew then 'creation' else 'update'
    # path in change must ends original path
    assert.isNotNull item.path.match new RegExp "#{instance.path.replace /\\/g, '\\\\'}$"
    assert.equal item.isFolder, instance.isFolder
    assert.equal item.content, instance.content
    awaited = true

  # when saving it
  awaited = false
  item.save (err, result) ->

    throw new Error "Can't save #{if isFolder then 'folder' else 'file'}: #{err}" if err?
    assert.equal item.path, result.path
    assert.equal isFolder, result.isFolder
    assert.equal content, result.content

    # then it's on the file system
    fs.stat item.path, (err, stats) ->
      throw new Error "Can't analyse #{if isFolder then 'folder' else 'file'}: #{err}" if err?
      assert.equal isFolder, stats.isDirectory()
      assert.ok awaited, 'watcher wasn\'t invoked'
      done()

# Simple code factorization on fs-items destruction
#
# @param item [FSItem] removed item
# @param done [Function] test done function.
assertFSItemRemove = (item, done) ->
  # then a creation event was issued
  watcher.once 'change', (operation, className, instance)->
    assert.equal className, 'FSItem'
    assert.equal operation, 'deletion'
    # path in change must ends original path
    assert.isNotNull item.path.match new RegExp "#{instance.path.replace /\\/g, '\\\\'}$"
    assert.equal item.isFolder, instance.isFolder
    awaited = true

  # when saving it
  awaited = false
  item.remove (err, result) ->
    throw new Error "Can't remove #{if item.isFolder then 'folder' else 'file'}: #{err}" if err?
    assert.ok item.equals result

    # then it's not on the file system anymore
    fs.exists item.path, (exists) ->
      assert.ok !exists, "#{if item.isFolder then 'folder' else 'file'} still exists"
      assert.ok awaited, 'watcher wasn\'t invoked'
      done()

# Empties the root folder and re-creates it.
cleanRoot = (done) ->
  root = utils.confKey 'game.source'
  fsExtra.remove root, (err) ->
    fsExtra.mkdir root, (err) ->
      throw new Error err if err?
      done()


describe 'FSItem tests', -> 

  describe 'given an empty root', ->

    beforeEach cleanRoot

    it 'should file be created', (done) -> 
      # given a new file
      item = new FSItem "#{root}/file.txt", false
      assertFSItemSave item, false, done

    it 'should folder be created', (done) -> 
      # given a new file
      item = new FSItem "#{root}/folder", true
      assertFSItemSave item, true, done

    it 'should file be created inside new folders', (done) -> 
      # given a new file inside unexisting folders
      item = new FSItem "#{root}/folder/folder/file1.txt", false
      assertFSItemSave item, false, done

    it 'should folder be created inside new folders', (done) -> 
      # given a new file
      item = new FSItem "#{root}/folder/folder/folder", true
      assertFSItemSave item, true, done

  describe 'given an existing file', ->

    file1 = null

    before (done) ->
      cleanRoot ->
        file1 = new FSItem "#{root}/file.txt", false
        file1.content = new Buffer 'yeah !'
        file1.save (err, result) ->
          throw new Error err if err?
          file1 = result
          done()

    it 'should file content be read', (done) ->
      # when reading file content
      file1.read (err, result) ->
        throw new Error "Can't read file content: #{err}" if err?
        # then content is available
        assert.equal new Buffer(result.content, 'base64').toString(), 'yeah !'
        done()

    it 'should file be updated', (done) ->
      newContent = new Buffer 'coucou 1'
      file1.content = newContent
      # when saginv it         
      assertFSItemSave file1, false, newContent.toString('base64'), false, ->
        # then the content was written on file system
        fs.readFile file1.path, (err, content) ->
          throw new Error "Can't read file content: #{err}" if err?
          assert.equal newContent.toString('base64'), content.toString('base64')
          done()

    it 'should file be removed', (done) ->
      assertFSItemRemove file1, done

  describe 'given an existing folder', ->

    folder1 = null

    before (done) ->
      cleanRoot ->
        new FSItem("#{root}/folder", true).save (err, result) ->
          throw new Error err if err?
          folder1 = result
          done()
          
    it 'should folder content be read', (done) ->
      # given several files inside folder
      content = [
        new FSItem "#{folder1.path}/file1.txt", false
        new FSItem "#{folder1.path}/file2.txt", false
        new FSItem "#{folder1.path}/folder/file3.txt", false
        new FSItem "#{folder1.path}/folder/file4.txt", false
      ]
      async.forEach content, (item, next) ->
        item.save next
      , ->
        # when reading file content
        folder1.read (err, result) ->
          throw new Error "Can't read folder content: #{err}" if err?
          # then folder was read
          assert.isNotNull result.content
          assert.equal 3, result.content.length
          assert.ok content[0].equals(result.content[0]), 'first file not read'
          assert.ok content[1].equals(result.content[1]), 'seconf file not read'
          assert.ok new FSItem("#{folder1.path}/folder", true).equals(result.content[2]), 'subfolder not read'
          done()

    it 'should folder be removed', (done) ->
      assertFSItemRemove folder1, done