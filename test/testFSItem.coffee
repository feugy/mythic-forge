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

pathUtils = require 'path'
fs = require 'fs-extra'
async = require 'async'
_ = require 'underscore'
testUtils = require './utils/testUtils'
FSItem = require '../hyperion/src/model/FSItem'
utils = require '../hyperion/src/util/common'
watcher = require('../hyperion/src/model/ModelWatcher').get()
assert = require('chai').assert

root = null
awaited = false
deletionAwaited = false
creationAwaited = false

# Simple code factorization on fs-items creation
#
# @param item [FSItem] saved item
# @param isFolder [Boolean] awaited folder status
# @param content [String|Buffer|Array] optionnal item content. null by default
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

    return done "Can't save #{if isFolder then 'folder' else 'file'}: #{err}" if err?
    assert.equal item.path, result.path
    assert.equal isFolder, result.isFolder
    assert.equal content, result.content

    # then it's on the file system
    fs.stat item.path, (err, stats) ->
      return done "Can't analyse #{if isFolder then 'folder' else 'file'}: #{err}" if err?
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
    return done "Can't remove #{if item.isFolder then 'folder' else 'file'}: #{err}" if err?
    assert.ok item.equals result

    # then it's not on the file system anymore
    fs.exists item.path, (exists) ->
      assert.ok !exists, "#{if item.isFolder then 'folder' else 'file'} still exists"
      assert.ok awaited, 'watcher wasn\'t invoked'
      done()

# Simple code factorization on fs-items move and rename
#
# @param item [FSItem] originaly saved item
# @param newPath [String] new path for this item
# @param isFolder [Boolean] awaited folder status
# @param content [String|Buffer|Array] optionnal item content. null by default
# @param done [Function] test done function.
assertFSItemMoved = (item, newPath, isFolder, content, done) ->
  if 'function' is utils.type content
    done = content
    content = null

  newPath = pathUtils.normalize newPath
  oldPath = "#{item.path}"

  # then a creation and a delection event were issued
  watcher.on 'change', listener = (operation, className, instance)->
    assert.equal className, 'FSItem'
    if operation is 'creation'
      assert.isNotNull newPath.match new RegExp "#{instance.path.replace /\\/g, '\\\\'}$"
      assert.equal instance.isFolder, isFolder
      assert.equal instance.content, content unless isFolder
      creationAwaited = true
    else if operation is 'deletion'
      assert.isNotNull oldPath.match new RegExp "#{instance.path.replace /\\/g, '\\\\'}$"
      assert.equal instance.isFolder, isFolder
      deletionAwaited = true

  creationAwaited = false
  deletionAwaited = false
  # when moving it
  item.move newPath, (err, result) ->

    return done "Can't move #{if isFolder then 'folder' else 'file'}: #{err}" if err?
    assert.equal result.path, newPath
    assert.equal result.isFolder, isFolder
    assert.equal result.content, content unless isFolder

    # then the old path does not exists anymore
    fs.exists oldPath, (exists) ->
      assert.isFalse exists, "old path #{oldPath} still exists"

      # then it's on the file system
      fs.stat newPath, (err, stats) ->

        return done "Can't analyse #{if isFolder then 'folder' else 'file'}: #{err}" if err?
        assert.equal stats.isDirectory(), isFolder
        assert.ok deletionAwaited, 'deletion event not received'
        assert.ok creationAwaited, 'creation event not received'
        watcher.removeListener 'change', listener
        done()

# Empties the root folder and re-creates it.
cleanRoot = (done) ->
  root = utils.confKey 'game.dev'
  testUtils.remove root, (err) ->
    return done err if err?
    fs.mkdirs root, done

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
      cleanRoot (err) ->
        return done err if err?
        file1 = new FSItem "#{root}/file.txt", false
        file1.content = new Buffer 'yeah !'
        file1.save (err, result) ->
          return done err if err?
          file1 = result
          done()

    it 'should file content be read', (done) ->
      # when reading file content
      file1.read (err, result) ->
        return done "Can't read file content: #{err}" if err?
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
          return done "Can't read file content: #{err}" if err?
          assert.equal newContent.toString('base64'), content.toString('base64')
          done()

    it 'should file be renamed', (done) ->
      assertFSItemMoved file1, "#{root}/file.copy", false, file1.content, done
     
    it 'should file be moved into another folder', (done) ->
      assertFSItemMoved file1, "#{root}/folder2/file.copy2", false, file1.content, done   

    it 'should file be removed', (done) ->
      assertFSItemRemove file1, done

  describe 'given an existing folder', ->

    folder1 = null

    before (done) ->
      cleanRoot (err) ->
        return done err if err?
        new FSItem("#{root}/folder", true).save (err, result) ->
          return done err if err?
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
        content.sort (a, b) -> a.path - b.path
        # when reading file content
        folder1.read (err, result) ->
          return done "Can't read folder content: #{err}" if err?
          # then folder was read
          assert.isNotNull result.content
          assert.equal 3, result.content.length
          assert.ok content[0].equals(result.content[0]), 'first file not read'
          assert.ok content[1].equals(result.content[1]), 'second file not read'
          assert.ok new FSItem("#{folder1.path}/folder", true).equals(result.content[2]), 'subfolder not read'
          done()

    it 'should folder be renamed', (done) ->
      assertFSItemMoved folder1, "#{root}/folder2", true, done
     
    it 'should file be moved into another folder', (done) ->
      assertFSItemMoved folder1, "#{root}/folder3/folder", true, done   

    it 'should folder be removed', (done) ->
      assertFSItemRemove folder1, done

  describe 'given an existing files and a folders', ->

    files = []
    folders = []

    before (done) ->
      cleanRoot (err) ->
        return done err if err?
        fixtures = [
          item: new FSItem("#{root}/file.txt", false)
          content: files
        ,
          item: new FSItem("#{root}/file2.txt", false)
          content: files
        ,
          item: new FSItem("#{root}/folder", true)
          content: folders
        ,
          item: new FSItem("#{root}/folder/folder2", true)
          content: folders
        ]
        async.forEach fixtures, (spec, next) ->
          spec.item.save (err, result) ->
            next err if err?
            spec.content.push result
            next()
        , (err) ->
          return done err if err?
          done()

    it 'should file not be moved into folder', (done) ->
      files[0].isFolder = true
      files[0].move folders[0].path, (err, result) ->
        files[0].isFolder = false
        assert.ok -1 isnt err.indexOf('move file'), "unexpected error: #{err}"
        done()

    it 'should file not be moved into existing file', (done) ->
      files[0].move files[1].path, (err, result) ->
        assert.ok -1 isnt err.indexOf('already exists'), "unexpected error: #{err}"
        done()

    it 'should file not be moved into existing folder', (done) ->
      files[0].move folders[0].path, (err, result) ->
        assert.ok -1 isnt err.indexOf('already exists'), "unexpected error: #{err}"
        done()

    it 'should folder not be moved into file', (done) ->
      folders[0].isFolder = false
      folders[0].move files[0].path, (err, result) ->
        folders[0].isFolder = true
        assert.ok -1 isnt err.indexOf('move folder'), "unexpected error: #{err}"
        done()

    it 'should folder not be moved into existing folder', (done) ->
      folders[0].move folders[1].path, (err, result) ->
        assert.ok -1 isnt err.indexOf('already exists'), "unexpected error: #{err}"
        done()

    it 'should folder not be moved into existing file', (done) ->
      folders[0].move files[0].path, (err, result) ->
        assert.ok -1 isnt err.indexOf('already exists'), "unexpected error: #{err}"
        done()

    it 'should folder not be saved again', (done) ->
      folders[0].save (err, result) ->
        assert.ok -1 isnt err.indexOf('existing folder'), "unexpected error: #{err}"
        done()

    it 'should unexisting folder not be removed', (done) ->
      new FSItem("#{root}/unknown", true).remove (err, result) ->
        assert.ok -1 isnt err.indexOf('Unexisting item'), "unexpected error: #{err}"
        done()

    it 'should unexisting file not be removed', (done) ->
      new FSItem("#{root}/unknown", false).remove (err, result) ->
        assert.ok -1 isnt err.indexOf('Unexisting item'), "unexpected error: #{err}"
        done()

    it 'should unexisting folder not be read', (done) ->
      new FSItem("#{root}/unknown", true).read (err, result) ->
        assert.ok -1 isnt err.indexOf('Unexisting item'), "unexpected error: #{err}"
        done()

    it 'should unexisting file not be read', (done) ->
      new FSItem("#{root}/unknown", false).read (err, result) ->
        assert.ok -1 isnt err.indexOf('Unexisting item'), "unexpected error: #{err}"
        done()

    it 'should folder not be saved into file', (done) ->
      folders[0].isFolder = false
      folders[0].save (err, result) ->
        folders[0].isFolder = true
        assert.ok -1 isnt err.indexOf('save folder'), "unexpected error: #{err}"
        done()

    it 'should file not be saved into folder', (done) ->
      files[0].isFolder = true
      files[0].save (err, result) ->
        files[0].isFolder = false
        assert.ok -1 isnt err.indexOf('save file'), "unexpected error: #{err}"
        done()