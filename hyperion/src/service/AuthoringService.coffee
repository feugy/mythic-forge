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
'use strict'

_ = require 'underscore'
FSItem = require '../model/FSItem'
Executable = require '../model/Executable'
{resolve, normalize, join, relative, extname} = require 'path'
{purgeFolder, confKey, fromRule} = require '../util/common'
logger = require('../util/logger').getLogger 'service'
versionService = require('./VersionService').get()
deployementService = require('./DeployementService').get()
notifier = require('../service/Notifier').get()

executablesRoot = resolve normalize confKey 'game.executable.source'
imagesRoot = resolve normalize confKey 'game.image'
root = null

# Singleton instance
_instance = undefined
module.exports = class AuthoringService

  @get: ->
    _instance ?= new _AuthoringService()

# The AuthoringService export feature relative to game client.
# It's a singleton class. The unic instance is retrieved by the `get()` method.
class _AuthoringService

  # Service constructor. Invoke init()
  # Triggers 'initialized' event on singleton instance when ready.
  constructor: ->
    @init (err) =>
      throw new Error "Failed to init: #{err}" if err?

  # Initialize folders and git repository.
  # 
  # @param callback [Function] initialization end callback.
  # @option callback err [Sting] error message. Null if no error occured.
  init: (callback) =>
    return if fromRule callback
    versionService.init (err) =>
      return callback err if err?
      root = resolve normalize confKey 'game.client.dev'
      callback null

  # Retrieves the root FSItem, populated with its content.
  #
  # @param callback [Function] end callback, invoked with two arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback root [FSItem] the root fSItem folder, populated
  readRoot: (callback) =>
    return if fromRule callback
    new FSItem(root, true).read (err, rootFolder) =>
      return callback "Failed to get root content: #{purgeFolder err, root}" if err?
      # make root relative
      rootFolder.path = ''
      file.path = relative root, file.path for file in rootFolder.content
      callback null, rootFolder

  # Saves a given FSItem, creating it if necessary. File FSItem can be updated with new content.
  # A creation or update event will be triggered.
  # File content must base64 encoded
  #
  # @param item [FSItem] saved FSItem
  # @param callback [Function] end callback, invoked with two arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback saved [FSItem] the saved fSItem
  save: (item, email, callback) =>
    return if fromRule callback
    deployed = deployementService.deployedVersion()
    return callback "Deployment of version #{deployed} in progress" if deployed?
    try 
      item = new FSItem item
    catch exc
      return callback "Only FSItem are supported: #{exc}"
    # make relative path absolute
    item.path = resolve root, item.path
    # saves it
    item.save (err, saved, isNew) =>
      return callback purgeFolder err, root if err?
      # makes fs-item relative to root
      saved.path = relative root, saved.path
      callback null, saved

  # Removes a given FSItem, with all its content.
  # Only one deletion event will be triggered.
  #
  # @param item [FSItem] removed FSItem
  # @param email [String] the author email, that must be an existing player email
  # @param callback [Function] end callback, invoked with two arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback removed [FSItem] the removed fSItem
  remove: (item, email, callback) =>
    return if fromRule callback
    deployed = deployementService.deployedVersion()
    return callback "Deployment of version #{deployed} in progress" if deployed?
    try 
      item = new FSItem item
    catch exc
      return callback "Only FSItem are supported: #{exc}"
    # make relative path absolute
    item.path = resolve root, item.path
    # removes it
    item.remove (err, removed) =>
      return callback purgeFolder err, root if err?
      logger.debug "#{removed.path} removed"
      # makes fs-item relative to root
      removed.path = relative root, removed.path
      callback null, removed

  # Moves and/or renames a given FSItem, with all its content.
  # A deletion and a creation events will be triggered.
  #
  # @param item [FSItem] moved FSItem
  # @param newPath [String] new path for this item
  # @param email [String] the author email, that must be an existing player email
  # @param callback [Function] end callback, invoked with two arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback moved [FSItem] the moved fSItem
  move: (item, newPath, email, callback) =>
    return if fromRule callback
    deployed = deployementService.deployedVersion()
    return callback "Deployment of version #{deployed} in progress" if deployed?
    try 
      item = new FSItem item
    catch exc
      return callback "Only FSItem are supported: #{exc}"
    # make relative path absolute
    item.path = resolve root, item.path
    # moves it, to an absolute new path
    item.move resolve(root, newPath), (err, moved) =>
      return callback purgeFolder err, root if err?
      # makes fs-item relative to root
      moved.path = relative root, moved.path
      callback null, moved

  # Retrieves the FSItem content, either file or folder.
  # File content is returned base64 encoded
  #
  # @param item [FSItem] read FSItem
  # @param newPath [String] new path for this item
  # @param callback [Function] end callback, invoked with two arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback read [FSItem] the read fSItem populated with its content
  read: (item, callback) =>
    return if fromRule callback
    try 
      item = new FSItem item
    catch exc
      return callback "Only FSItem are supported: #{exc}"
    # make relative path absolute
    item.path = resolve root, item.path
    # read its content
    item.read (err, read) =>
      return callback purgeFolder err, root if err?
      # makes fs-item relative to root
      read.path = relative root, read.path
      # process also folder content
      if read.isFolder
        file.path = relative(root, file.path) for file in read.content
      callback null, read

  # Retrieves history of an executable or a file. Folders do not have history.
  #
  # @param item [FSItem|Executable] consulted file or executable
  # @param callback [Function] end callback, invoked with two arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback obj [FSItem|Executable] concerned file or executable
  # @option callback history [Array] array of commits, each an object containing `message`, `author`, `date` and `id`
  history: (item, callback) =>
    return if fromRule callback
    path = null
    obj = null
    if _.isObject(item) and item?.id
      try
        # convert into Executable
        obj = new Executable item
        path = obj.path
      catch exc
        return callback "Only Executable and FSItem files are supported: #{exc}"
    else
      try 
        # convert into FSItem
        obj = new FSItem item
        path = join root, obj.path
      catch exc
        return callback "Only Executable and FSItem files are supported: #{exc}"
      return callback 'History not supported on folders' if obj.isFolder

    # consult file history
    versionService.history path, (err, history) =>
      return callback "Failed to get history: #{err}" if err?
      callback null, obj, history

  # Retrieves all files that have been deleted in repository.
  #
  # @param filters [Array<String>] result filters, to get only 'Executable', 'FSItem' and or d 'Image'. Empty to get all
  # @param callback [Function] end callback, invoked with two arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback restorables [Array] array of restorable FSItems|Executables. (may be empty). 
  # For each item contains an object with `id` (commit id), `item` (object model) and `className` (model class name) attributes
  restorables: (filters, callback) =>
    return if fromRule callback
    versionService.restorables (err, restorables) =>
      return callback "Failed to get restorable list: #{err}" if err?
      results = []

      fileRoot = root.replace(versionService.repo.path, '')[1..]
      exeRoot = executablesRoot.replace(versionService.repo.path, '')[1..]
      imgRoot = imagesRoot.replace(versionService.repo.path, '')[1..]
      for restorable in restorables
        className = null
        if 0 is restorable.path.indexOf fileRoot
          # an FSItem
          className = 'FSItem'
          obj = new FSItem {isFolder: false, path: restorable.path[fileRoot.length+1..]}
        else if 0 is restorable.path.indexOf exeRoot
          # an executable.
          className = 'Executable'
          ext = extname restorable.path
          obj = new Executable
            id: restorable.path[exeRoot.length+1..].replace ext, ''
            lang: ext[1..]

        else
          # an image
          className = 'Image'
          obj = path: restorable.path[imgRoot.length+1..]

        # may filter results to only what's required
        if filters.length is 0 or className in filters
          results.push 
            item: obj
            className: className
            id: restorable.id

      callback err, results

  # Retrieves a file or executable content to a given version. Folders do not have history.
  # File content is returned base64 encoded
  #
  # @param item [FSItem|Executable] consulted file or executable
  # @param version [String] commit id of the concerned version
  # @param callback [Function] end callback, invoked with two arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback obj [FSItem|Executable] concerned file or executable
  # @option callback content [String] the base64 encoded content
  readVersion: (item, version, callback) =>
    return if fromRule callback
    path = null
    obj = null
    if _.isObject(item) and item?.id
      try
        # convert into Executable
        obj = new Executable item
        path = obj.path
      catch exc
        return callback "Only Executable and FSItem files are supported: #{exc}"
    else
      try 
        # convert into FSItem
        obj = new FSItem item
        path = join root, obj.path
      catch exc
        return callback "Only Executable and FSItem files are supported: #{exc}"
      return callback 'History not supported on folders' if obj.isFolder

    # show file at specified revision
    versionService.readVersion path, version, (err, content) => callback err, obj, content