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

FSItem = require '../model/FSItem'
pathUtils = require 'path'
utils = require '../utils'
logger = require('../logger').getLogger 'service'

root = utils.confKey 'game.source'

# enforce root folder existence at startup.
utils.enforceFolderSync root, false, logger

# The AuthoringService export feature relative to game client.
# It's a singleton class. The unic instance is retrieved by the `get()` method.
class _AuthoringService

  # Retrieves the root FSItem, populated with its content.
  #
  # @param callback [Function] end callback, invoked with two arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback root [FSItem] the root fSItem folder, populated
  getRootFSItem: (callback) =>
    new FSItem(root, true).read (err, rootFolder) =>
      return callback "Failed to get root content: #{err}" if err?
      # make root relative
      rootFolder.path = ''
      file.path = pathUtils.relative(root, file.path) for file in rootFolder.content
      callback null, rootFolder

  # Saves a given FSItem, creating it if necessary. File FSItem can be updated with new content.
  # A creation or update event will be triggered.
  #
  # @param item [FSItem] saved FSItem
  # @param callback [Function] end callback, invoked with two arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback saved [FSItem] the saved fSItem
  saveFSItem: (item, callback) =>
    try 
      item = new FSItem item
    catch exc
      return callback "Only FSItem are supported: #{exc}"
    # make relative path absolute
    item.path = pathUtils.resolve root, item.path
    # saves it
    item.save (err, saved) =>
      return callback err if err?
      # makes fs-item relative to root
      saved.path = pathUtils.relative root, saved.path
      callback null, saved

  # Removes a given FSItem, with all its content.
  # Only one deletion event will be triggered.
  #
  # @param item [FSItem] removed FSItem
  # @param callback [Function] end callback, invoked with two arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback removed [FSItem] the removed fSItem
  removeFSItem: (item, callback) =>
    try 
      item = new FSItem item
    catch exc
      return callback "Only FSItem are supported: #{exc}"
    # make relative path absolute
    item.path = pathUtils.resolve root, item.path
    # removes it
    item.remove (err, removed) =>
      return callback err if err?
      # makes fs-item relative to root
      removed.path = pathUtils.relative root, removed.path
      callback null, removed

  # Moves and/or renames a given FSItem, with all its content.
  # A deletion and a creation events will be triggered.
  #
  # @param item [FSItem] moved FSItem
  # @param newPath [String] new path for this item
  # @param callback [Function] end callback, invoked with two arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback moved [FSItem] the moved fSItem
  moveFSItem: (item, newPath, callback) =>
    try 
      item = new FSItem item
    catch exc
      return callback "Only FSItem are supported: #{exc}"
    # make relative path absolute
    item.path = pathUtils.resolve root, item.path
    # moves it, to an absolute new path
    item.move pathUtils.resolve(root, newPath), (err, moved) =>
      return callback err if err?
      # makes fs-item relative to root
      moved.path = pathUtils.relative root, moved.path
      callback null, moved

  # Retrieves the FSItem content, either file or folder.
  #
  # @param item [FSItem] read FSItem
  # @param newPath [String] new path for this item
  # @param callback [Function] end callback, invoked with two arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback read [FSItem] the read fSItem populated with its content
  readFSItem: (item, callback) =>
    try 
      item = new FSItem item
    catch exc
      return callback "Only FSItem are supported: #{exc}"
    # make relative path absolute
    item.path = pathUtils.resolve root, item.path
    # read its content
    item.read (err, read) =>
      return callback err if err?
      # makes fs-item relative to root
      read.path = pathUtils.relative root, read.path
      # process also folder content
      if read.isFolder
        file.path = pathUtils.relative(root, file.path) for file in read.content
      callback null, read

# Singleton instance
_instance = undefined
class AuthoringService
  @get: ->
    _instance ?= new _AuthoringService()

module.exports = AuthoringService