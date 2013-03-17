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
'use strict'

_ = require 'underscore'
pathUtils = require 'path'
fs = require 'fs-extra'
async = require 'async'
utils = require '../util/common'
modelWatcher = require('./ModelWatcher').get()
logger = require('../util/logger').getLogger 'model'

# hashmap to differentiate creations from updates
wasNew= {}

# FSItem represents both files and folder on the file system
# Triggers event on ModelWatcher utility class
class FSItem

  # Item's path and name, relative to the game client's root folder
  # Do not change after creation, a rename method is intended to rename fsitems
  path: ''

  # Allows to distinguish folder from files
  isFolder: false

  # For file items, binary content encoded in base64.
  # For folder items, an array (may be empty) of FSItems.
  content: null

  # Create a new fs-item, with its path and folder status
  # 
  # @overload new FSItem (path, isFolder)
  #   Creates an FSItem
  #   @param path [String] item's path and name
  #   @param isFolder [Boolean] allows to distinguish folder from files
  # 
  # @overload new FSItem (raw)
  #   Creates an FSItem from a JSON Object
  #   @param raw [Object] JSON representation of an FSItem
  #   @option raw path [String] item's path and name
  #   @option raw isFolder [Boolean] allows to distinguish folder from files
  #   @option raw content [String] base64 encoded string with file content (for files only)
  #   @throws error if the raw object does'nt have right fields
  constructor: (args...) ->
    switch args.length
      when 1 
        raw = args[0]
        throw 'FSItem may be constructed from JSON object' unless 'object' is utils.type raw
        @[attr] = value for attr, value of raw when attr in ['path', 'content', 'isFolder']
      when 2
        @path = args[0]
        @isFolder = args[1]          
      else throw 'Can only construct FSItem with arguments `raw` or `path`and `isFolder`'
    # process attributes
    @path = pathUtils.normalize @path
    @content = @content.toString 'base64' if Buffer.isBuffer @content

  # Find fs-item content. If the searched fs-item is a folder, @content will contains
  # an array of FSItems, and if it's a file, @content will be a base64 encoded string
  #
  # @param callback [Function] invoked when new content is saved
  # @option callback err [String] an error message if an error occured. null otherwise
  # @option callback item [FSItem] the populated fsitem
  read: (callback) ->
    # First, read current file statistics
    fs.stat @path, (err, stat) =>
      return callback "Unexisting item #{@path} cannot be read" if err?.code is 'ENOENT'
      return callback "Cannot read item: #{err}" if err?
      # check that folder status do not change
      return callback "Incompatible folder status (#{@isFolder} for #{@path}" if @isFolder isnt stat.isDirectory()
      
      if @isFolder
        # read folder's content
        fs.readdir @path, (err, items) =>
          return callback "Cannot read folder content: #{err}" if err?
          @content = []
          # construct FSItem for each contained item
          async.forEach items, (item, next) =>
            path = pathUtils.join(@path, item)
            # test if item is folder or file
            fs.stat path, (err, stat) =>
              return next(err) if err?
              @content.push new FSItem path, stat.isDirectory()
              next()
          , (err) =>
            if err?
              @content = null
              return callback "Cannot construct folder content: #{err}" if err?
            @content = _.sortBy @content, 'path' # sort to get always consistent results
            callback null, @

      else
        # read file's content
        fs.readFile @path, (err, content) =>
          return callback "Cannot read file content: #{err}" if err?
          @content = content.toString 'base64'
          callback null, @

  # Save (or update) a fs-item and its content.
  # Folder status cannot be changed.
  # Folder cannot be saved once created
  # 
  # @param callback [Function] called when the save is finished, with three arguments:
  # @option callback err [String] error string. Null if save succeeded
  # @option callback item [FSItem] the saved item
  # @option callback isNew [Boolean] true if the item did not exists before
  save: (callback) =>
    # First, read current file statistics
    fs.stat @path, (err, stat) =>
      isNew = false
      if err?
        return callback "Cannot read item stat: #{err}" unless err.code is 'ENOENT'
        isNew = true

      # check that folder status do not change
      if !isNew and @isFolder isnt stat.isDirectory()
        return callback "Cannot save #{if @isFolder then 'file' else 'folder'} #{@path} into #{if @isFolder then 'folder' else 'file'}"

      if @isFolder 
        # Creates folder
        if isNew
          fs.mkdirs @path, (err) => 
            return callback "Error while creating new folder #{@path}: #{err}" if err?
            logger.debug "folder #{@path} successfully created"
            # invoke watcher
            modelWatcher.change 'creation', 'FSItem', @
            callback null, @, true
        else
          callback "Cannot save existing folder #{@path}"

      else
        saveFile = =>
          try
            # save with binary buffer, or empty string, but keep base64 string as content
            saved = ''
            if Buffer.isBuffer @content
              saved = @content
              @content = @content.toString 'base64' 
            else if 'string' is utils.type @content
              saved = new Buffer @content, 'base64'

            # write file content
            fs.writeFile @path, saved, (err) =>
              return callback "Error while saving file #{@path}: #{err}" if err?
              logger.debug "file #{@path} successfully saved"
              modelWatcher.change (if isNew then 'creation' else 'update'), 'FSItem', @, ['content']
              callback null, @, isNew
          catch exc
            callback "Bad file content for file #{@path}: #{exc}"

        return saveFile() unless isNew
        # for new files, create parent folders
        parent = pathUtils.dirname @path
        fs.mkdirs parent, (err) =>
          return callback "Error while creating new file #{@path}: #{err}" if err?
          saveFile()

  # Remove an existing fs-item.
  # 
  # @param callback [Function] called when the removal is finished, with two arguments:
  #   @param err [String] error string. Null if save succeeded
  #   @param item [FSItem] the removed item
  remove: (callback) =>
    # First, read current file statistics
    fs.stat @path, (err, stat) =>
      return callback "Unexisting item #{@path} cannot be removed" if err?.code is 'ENOENT'
      @isFolder = stat.isDirectory()

      if @isFolder 
        # removes folder and its content
        fs.remove @path, (err) => 
          return callback "Error while removing folder #{@path}: #{err}" if err?
          logger.debug "folder #{@path} successfully removed"
          modelWatcher.change 'deletion', 'FSItem', @
          callback null, @

      else
        # removes file
        fs.unlink @path, (err) =>
          return callback "Error while removing file #{@path}: #{err}" if err?
          logger.debug "file #{@path} successfully removed"
          modelWatcher.change 'deletion', 'FSItem', @
          callback null, @

  # Allows to move and rename the current fs-item
  # In case of folder move, sub-items are moved too
  #
  # @param newPath [String] the new item path
  # @param callback [Function] invoked when move operation is finished
  # @option callback err [String] an error message if an error occured. null otherwise
  # @option callback item [FSItem] the concerned fsitem
  move: (newPath, callback) =>
    newPath = pathUtils.normalize newPath
    # First, read current file statistics
    fs.stat @path, (err, stat) =>
      return callback "Unexisting item #{@path} cannot be moved" if err?.code is 'ENOENT'
      return callback "Cannot read item stat: #{err}" if err?
      # check that folder status do not change
      if @isFolder isnt stat.isDirectory()
        return callback "Cannot move #{if @isFolder then 'file' else 'folder'} #{@path} into #{if @isFolder then 'folder' else 'file'}"

      # then checks that new path does not exists
      fs.exists newPath, (exists) =>
        return callback "Cannot move because new path #{newPath} already exists" if exists

        # then creates the new parent path
        parent = pathUtils.dirname newPath
        fs.mkdirs parent, (err) =>
          return callback "Error while creating new item #{@path}: #{err}" if err?

          # then performs copy
          fs.copy @path, newPath, (err) =>
            return callback "Cannot copy item #{@path} to #{newPath}: #{err}" if err?

            # and eventually remove old value
            fs.remove @path, (err) => 
              return callback "Error while removing olf item #{@path}: #{err}" if err?

              logger.debug "item #{@path} successfully moved to #{newPath}"
              # invoke watcher for deletion
              modelWatcher.change 'deletion', 'FSItem', new FSItem @path, @isFolder

              # and for creation
              @path = newPath
              modelWatcher.change 'creation', 'FSItem', @
              callback null, @

  # Provide the equals() method to check correctly the equality between paths.
  #
  # @param other [Object] other object against which the current object is compared
  # @return true if both objects have the same path, false otherwise
  equals: (object) =>
    @path is object?.path

module.exports = FSItem
