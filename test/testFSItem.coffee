###
  Copyright 2010~2014 Damien Feugas

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
_ = require 'lodash'
FSItem = require '../hyperion/src/model/FSItem'
utils = require '../hyperion/src/util/common'
watcher = require('../hyperion/src/model/ModelWatcher').get()
{expect} = require 'chai'

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
expectFSItemSave = (item, isFolder, content, isNew, done) ->
  if 'function' is utils.type content
    done = content
    content = null
    isNew = true
  else if 'function' is utils.type isNew
    done = isNew
    isNew = true

  # then a creation event was issued
  watcher.once 'change', (operation, className, instance)->
    expect(className).to.equal 'FSItem'
    expect(operation).to.equal if isNew then 'creation' else 'update'
    # path in change must ends original path
    expect(item.path).to.match new RegExp "#{instance.path.replace /\\/g, '\\\\'}$"
    expect(instance.isFolder).to.equal item.isFolder
    expect(instance.content).to.equal item.content
    awaited = true

  # when saving it
  awaited = false
  item.save (err, result) ->

    return done "Can't save #{if isFolder then 'folder' else 'file'}: #{err}" if err?
    expect(result.path).to.equal item.path
    expect(result.isFolder).to.equal isFolder
    expect(result.content).to.equal content
    expect(result).to.have.property 'updated'
    expect(result.updated.getTime()).to.equal new Date().setMilliseconds 0

    # then it's on the file system
    fs.stat item.path, (err, stats) ->
      return done "Can't analyse #{if isFolder then 'folder' else 'file'}: #{err}" if err?
      expect(isFolder).to.equal stats.isDirectory()
      expect(awaited, 'watcher wasn\'t invoked').to.be.true
      done()

# Simple code factorization on fs-items destruction
#
# @param item [FSItem] removed item
# @param done [Function] test done function.
expectFSItemRemove = (item, done) ->
  # then a creation event was issued
  watcher.once 'change', (operation, className, instance)->
    expect(className).to.equal 'FSItem'
    expect(operation).to.equal 'deletion'
    # path in change must ends original path
    expect(item.path).to.match new RegExp "#{instance.path.replace /\\/g, '\\\\'}$"
    expect(instance.isFolder).to.equal item.isFolder
    awaited = true

  # when saving it
  awaited = false
  item.remove (err, result) ->
    return done "Can't remove #{if item.isFolder then 'folder' else 'file'}: #{err}" if err?
    expect(result).to.satisfy (o) => o.equals item

    # then it's not on the file system anymore
    fs.exists item.path, (exists) ->
      expect(exists, "#{if item.isFolder then 'folder' else 'file'} still exists").to.be.false
      expect(awaited, 'watcher wasn\'t invoked').to.be.true
      done()

# Simple code factorization on fs-items move and rename
#
# @param item [FSItem] originaly saved item
# @param newPath [String] new path for this item
# @param isFolder [Boolean] awaited folder status
# @param content [String|Buffer|Array] optionnal item content. null by default
# @param done [Function] test done function.
expectFSItemMoved = (item, newPath, isFolder, content, done) ->
  if 'function' is utils.type content
    done = content
    content = null

  newPath = pathUtils.normalize newPath
  oldPath = "#{item.path}"

  # then a creation and a delection event were issued
  watcher.on 'change', listener = (operation, className, instance)->
    expect(className).to.equal 'FSItem'
    if operation is 'creation'
      expect(newPath).to.match new RegExp "#{instance.path.replace /\\/g, '\\\\'}$"
      expect(instance.isFolder).to.equal isFolder
      unless isFolder
        expect(instance.content).to.equal content
      creationAwaited = true
    else if operation is 'deletion'
      expect(oldPath).to.match new RegExp "#{instance.path.replace /\\/g, '\\\\'}$"
      expect(instance.isFolder).to.equal isFolder
      deletionAwaited = true

  creationAwaited = false
  deletionAwaited = false
  # when moving it
  item.move newPath, (err, result) ->

    return done "Can't move #{if isFolder then 'folder' else 'file'}: #{err}" if err?
    expect(result.path).to.equal newPath
    expect(result.isFolder).to.equal isFolder
    unless isFolder
      expect(result.content).to.equal content

    # then the old path does not exists anymore
    fs.exists oldPath, (exists) ->
      expect(exists, "old path #{oldPath} still exists").to.be.false

      # then it's on the file system
      fs.stat newPath, (err, stats) ->

        return done "Can't analyse #{if isFolder then 'folder' else 'file'}: #{err}" if err?
        expect(stats.isDirectory()).to.equal isFolder
        expect(deletionAwaited, 'deletion event not received').to.be.true
        expect(creationAwaited, 'creation event not received').to.be.true
        watcher.removeListener 'change', listener
        done()

# Empties the root folder and re-creates it.
cleanRoot = (done) ->
  root = utils.confKey 'game.client.dev'
  utils.remove root, (err) ->
    return done err if err?
    fs.mkdirs root, done

describe 'FSItem tests', ->

  describe 'given an empty root', ->

    beforeEach cleanRoot

    it 'should file be created', (done) ->
      # given a new file
      item = new FSItem "#{root}/file.txt", false
      expectFSItemSave item, false, done

    it 'should folder be created', (done) ->
      # given a new file
      item = new FSItem "#{root}/folder", true
      expectFSItemSave item, true, done

    it 'should file be created inside new folders', (done) ->
      # given a new file inside unexisting folders
      item = new FSItem "#{root}/folder/folder/file1.txt", false
      expectFSItemSave item, false, done

    it 'should folder be created inside new folders', (done) ->
      # given a new file
      item = new FSItem "#{root}/folder/folder/folder", true
      expectFSItemSave item, true, done

  describe 'given an existing file', ->

    file1 = null
    creation = null

    before (done) ->
      cleanRoot (err) ->
        return done err if err?
        file1 = new FSItem "#{root}/file.txt", false
        file1.content = new Buffer 'yeah !'
        creation = new Date()
        file1.save (err, result) ->
          return done err if err?
          file1 = result
          creation = file1.updated
          done()

    it 'should file content be read', (done) ->
      # when reading file content
      file1.read (err, result) ->
        return done "Can't read file content: #{err}" if err?
        # then content is available
        expect(file1.updated.getTime()).to.equal creation.getTime()
        expect(new Buffer(result.content, 'base64').toString()).to.equal 'yeah !'
        done()

    it 'should file be updated', (done) ->
      newContent = new Buffer 'coucou 1'
      file1.content = newContent
      creation = file1.updated
      # when saginv it
      expectFSItemSave file1, false, newContent.toString('base64'), false, ->
        # then the content was written on file system
        fs.readFile file1.path, (err, content) ->
          return done "Can't read file content: #{err}" if err?
          expect(file1.updated.getTime()).to.equal new Date().setMilliseconds 0
          expect(newContent.toString('base64')).to.equal content.toString('base64')
          expect(file1.updated).not.to.equal creation
          done()

    it 'should file be renamed', (done) ->
      expectFSItemMoved file1, "#{root}/file.copy", false, file1.content, done

    it 'should file be moved into another folder', (done) ->
      expectFSItemMoved file1, "#{root}/folder2/file.copy2", false, file1.content, done

    it 'should file be removed', (done) ->
      expectFSItemRemove file1, done

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
          expect(result.content).to.exist
          expect(result.content).to.have.lengthOf 3
          expect(content[0], 'first file not read').to.satisfy (o) => o.equals result.content[0]
          expect(content[1], 'second file not read').to.satisfy (o) => o.equals result.content[1]
          expect(new FSItem("#{folder1.path}/folder", true), 'subfolder not read').to.satisfy (o) => o.equals result.content[2]
          done()

    it 'should folder be renamed', (done) ->
      expectFSItemMoved folder1, "#{root}/folder2", true, done

    it 'should file be moved into another folder', (done) ->
      expectFSItemMoved folder1, "#{root}/folder3/folder", true, done

    it 'should folder be removed', (done) ->
      expectFSItemRemove folder1, done

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
        expect(err).to.include 'move file'
        done()

    it 'should file not be moved into existing file', (done) ->
      files[0].move files[1].path, (err, result) ->
        expect(err).to.include 'already exists'
        done()

    it 'should file not be moved into existing folder', (done) ->
      files[0].move folders[0].path, (err, result) ->
        expect(err).to.include 'already exists'
        done()

    it 'should folder not be moved into file', (done) ->
      folders[0].isFolder = false
      folders[0].move files[0].path, (err, result) ->
        folders[0].isFolder = true
        expect(err).to.include 'move folder'
        done()

    it 'should folder not be moved into existing folder', (done) ->
      folders[0].move folders[1].path, (err, result) ->
        expect(err).to.include 'already exists'
        done()

    it 'should folder not be moved into existing file', (done) ->
      folders[0].move files[0].path, (err, result) ->
        expect(err).to.include 'already exists'
        done()

    it 'should folder not be saved again', (done) ->
      folders[0].save (err, result) ->
        expect(err).to.include 'existing folder'
        done()

    it 'should unexisting folder not be removed', (done) ->
      new FSItem("#{root}/unknown", true).remove (err, result) ->
        expect(err).to.include 'Unexisting item'
        done()

    it 'should unexisting file not be removed', (done) ->
      new FSItem("#{root}/unknown", false).remove (err, result) ->
        expect(err).to.include 'Unexisting item'
        done()

    it 'should unexisting folder not be read', (done) ->
      new FSItem("#{root}/unknown", true).read (err, result) ->
        expect(err).to.include 'Unexisting item'
        done()

    it 'should unexisting file not be read', (done) ->
      new FSItem("#{root}/unknown", false).read (err, result) ->
        expect(err).to.include 'Unexisting item'
        done()

    it 'should folder not be saved into file', (done) ->
      folders[0].isFolder = false
      folders[0].save (err, result) ->
        folders[0].isFolder = true
        expect(err).to.include 'save folder'
        done()

    it 'should file not be saved into folder', (done) ->
      files[0].isFolder = true
      files[0].save (err, result) ->
        files[0].isFolder = false
        expect(err).to.include 'save file'
        done()