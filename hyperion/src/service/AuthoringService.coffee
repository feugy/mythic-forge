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
fs = require 'fs-extra'
git = require 'gift'
utils = require '../utils'
logger = require('../logger').getLogger 'service'
playerService = require('./PlayerService').get()
deployementService = require('./DeployementService').get()
notifier = require('../service/Notifier').get()

repo = null
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
    utils.initGameRepo logger, (err, _root, _repo) =>
      return callback err if err?
      root = _root
      repo = _repo
      callback null

  # Retrieves the root FSItem, populated with its content.
  #
  # @param callback [Function] end callback, invoked with two arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback root [FSItem] the root fSItem folder, populated
  readRoot: (callback) =>
    new FSItem(root, true).read (err, rootFolder) =>
      return callback "Failed to get root content: #{purge err}" if err?
      # make root relative
      rootFolder.path = ''
      file.path = pathUtils.relative root, file.path for file in rootFolder.content
      callback null, rootFolder

  # Saves a given FSItem, creating it if necessary. File FSItem can be updated with new content.
  # A creation or update event will be triggered.
  # File content must base64 encoded
  #
  # @param item [FSItem] saved FSItem
  # @param email [String] the author email, that must be an existing player email
  # @param callback [Function] end callback, invoked with two arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback saved [FSItem] the saved fSItem
  save: (item, email, callback) =>
    deployed = deployementService.deployedVersion()
    return callback "Deployment of version #{deployed} in progress" if deployed?
    playerService.getByEmail email, false, (err, author) =>
      return callback "Failed to get author: #{err}" if err?
      return callback "No author with email #{email}" unless author?
      try 
        item = new FSItem item
      catch exc
        return callback "Only FSItem are supported: #{exc}"
      # make relative path absolute
      item.path = pathUtils.resolve root, item.path
      # saves it
      item.save (err, saved, isNew) =>
        return callback purge err if err?

        finish = (commit =null) =>
          # makes fs-item relative to root
          saved.path = pathUtils.relative root, saved.path
          if commit?
            notifier.notify 'authoring', 'committed', saved.path, commit 
          callback null, saved

        # do not commit folders
        return finish() if saved.isFolder

        # but do it for files
        commit = =>
          # now commit it on git
          repo.commit 'save',
            all: true
            author: getAuthor author
          , (err, stdout) =>
            return callback "Failed to commit: #{purge err} #{purge stdout}" if err?
            logger.debug "#{saved.path} commited"
            # get the last commit, ignore errors
            repo.commits 'master', 1, 0, (err, history) =>
              unless err?
                commit =
                  id: history[0]?.id
                  message: history[0]?.message
                  author: history[0]?.author?.name
                  date: history[0]?.committed_date
              finish commit

        if isNew
          # first add it to git
          repo.add saved.path, (err, stdout) =>
            return callback "Failed to add to version control: #{purge err} #{purge stdout}" if err?
            logger.debug "#{saved.path} added to version control"
            commit()
        else 
          commit()

  # Removes a given FSItem, with all its content.
  # Only one deletion event will be triggered.
  #
  # @param item [FSItem] removed FSItem
  # @param email [String] the author email, that must be an existing player email
  # @param callback [Function] end callback, invoked with two arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback removed [FSItem] the removed fSItem
  remove: (item, email, callback) =>
    deployed = deployementService.deployedVersion()
    return callback "Deployment of version #{deployed} in progress" if deployed?
    playerService.getByEmail email, false, (err, author) =>
      return callback "Failed to get author: #{err}" if err? 
      return callback "No author with email #{email}" unless author?
      try 
        item = new FSItem item
      catch exc
        return callback "Only FSItem are supported: #{exc}"
      # make relative path absolute
      item.path = pathUtils.resolve root, item.path
      # removes it
      item.remove (err, removed) =>
        return callback purge err if err?

        # now commit it on git
        repo.commit 'remove',
          all: true
          author: getAuthor author
        , (err, stdout) =>
          # ignore commit failure on empty working directory
          err = null if err?.code is 1
          return callback "Failed to commit: #{purge err} #{purge stdout}" if err?
          logger.debug "#{removed.path} removed from version control"
          # makes fs-item relative to root
          removed.path = pathUtils.relative root, removed.path
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
    deployed = deployementService.deployedVersion()
    return callback "Deployment of version #{deployed} in progress" if deployed?
    playerService.getByEmail email, false, (err, author) =>
      return callback "Failed to get author: #{err}" if err
      return callback "No author with email #{email}" unless author?
      try 
        item = new FSItem item
      catch exc
        return callback "Only FSItem are supported: #{exc}"
      # make relative path absolute
      item.path = pathUtils.resolve root, item.path
      # moves it, to an absolute new path
      item.move pathUtils.resolve(root, newPath), (err, moved) =>
        return callback purge err if err?

        # add/remove new files into git
        repo.add [], all:true, (err, stdout) =>
          return callback "Failed to add to version control: #{purge err} #{purge stdout}" if err?
          logger.debug "#{moved.path} added to version control"
          
          # now commit it on git
          repo.commit 'move',
            all: true 
            author: getAuthor author
          , (err, stdout) =>
            noCommit = false
            # ignore commit failure on empty working directory
            if err?.code is 1
              err = null 
              noCommit = true
            return callback "Failed to commit: #{purge err} #{purge stdout}" if err?
            logger.debug "#{moved.path} commited"

            # makes fs-item relative to root
            moved.path = pathUtils.relative root, moved.path

            # get the last commit, ignore errors
            repo.commits 'master', 1, 0, (err, history) =>
              unless err?
                commit =
                  id: history[0]?.id
                  message: history[0]?.message
                  author: history[0]?.author?.name
                  date: history[0]?.committed_date

              notifier.notify 'authoring', 'committed', moved.path, commit unless noCommit
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
    try 
      item = new FSItem item
    catch exc
      return callback "Only FSItem are supported: #{exc}"
    # make relative path absolute
    item.path = pathUtils.resolve root, item.path
    # read its content
    item.read (err, read) =>
      return callback purge err if err?
      # makes fs-item relative to root
      read.path = pathUtils.relative root, read.path
      # process also folder content
      if read.isFolder
        file.path = pathUtils.relative(root, file.path) for file in read.content
      callback null, read

  # Retrieves history of an file. Folders do not have history.
  #
  # @param item [FSItem] consulted file
  # @param callback [Function] end callback, invoked with two arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback history [Array] array of commits, each an object containing `message`, `author`, `date` and `id`
  history: (item, callback) =>
    # convert into plain FSItem
    try 
      file = new FSItem item
    catch exc
      return callback "Only FSItem are supported: #{exc}"
    return callback 'History not supported on folders' if file.isFolder

    # consult file history
    utils.quickHistory repo, pathUtils.join(root, file.path), (err, history) =>
      return callback "Failed to get history on  FSItem are supported: #{err}" if err?
      callback null, history

  # Retrieves a file content to a given version. Folders do not have history.
  # File content is returned base64 encoded
  #
  # @param item [FSItem] consulted FSItem
  # @param version [String] commit id of the concerned version
  # @param callback [Function] end callback, invoked with two arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback content [String] the base64 encoded content
  readVersion: (item, version, callback) =>
    # convert into plain FSItem
    try 
      file = new FSItem item
    catch exc
      return callback "Only FSItem are supported: #{exc}"
    return callback 'History not supported on folders' if file.isFolder

    # item path must be / separated, and relative to repository root
    path = pathUtils.join(root, file.path).replace(repo.path, '').replace /\\/g, '\/'
    # show file at specified revision
    repo.git 'show', {}, "#{version}:.#{path}", (err, stdout, stderr) =>
      return callback "Failed to get version content: #{err}" if err?
      callback err, new Buffer(stdout, 'binary').toString 'base64'

#Simple method to remove occurence of the root path from error messages
purge = (err) -> 
  err = err.message if utils.isA err, Error
  err.replace new RegExp("#{root.replace /\\/g, '\\\\'}", 'g'), '' if 'string'

# Generate a proper Git author string, that ensure at least lastName and correct email
#
# @param player [Player] the concerned author
# @return the author string.
getAuthor = (player) ->
  firstName = player.get('firstName') or ''
  lastName = player.get('lastName') or ''
  lastName = 'unknown' unless lastName or firstName
  email = player.get 'email'
  email += '@unknown.org' unless -1 isnt email.indexOf '@'
  "#{firstName} #{lastName} <#{email}>"