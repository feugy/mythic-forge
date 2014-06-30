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

{join, resolve, normalize} = require 'path'
_ = require 'underscore'
fs = require 'fs-extra'
async = require 'async'
git = require 'gift'
{confKey, enforceFolderSync, removeSync, fromRule} = require '../util/common'
logger = require('../util/logger').getLogger 'service'

# The VersionService wrapped a Git repository to manage version for rules and 
# game client's files
class _VersionService

  # Folder under source control
  paths: 
    client: null
    images: null
    executables: null

  # Gift wrapper around git repository
  repo: null

  # Git user used for commits
  user:
    email: 'mythic.forge.adm@gmail.com'
    name: 'mythic-forge'

  # **private**
  # Root repository containing .git folder
  _root: null

  # **private**
  # flag to avoid multiple concurrent initialization on same repository
  _initInProgress: false

  # Build the service, and ensure that configuration is right
  constructor: ->
    @root = null
    @repo = null
    @_initInProgress = false
    # check that configuration values are correct
    @paths= 
      client: resolve normalize confKey 'game.client.dev'
      images: resolve normalize confKey 'game.image'
      executables: resolve normalize confKey 'game.executable.source'

    @_root = resolve normalize confKey 'game.repo'

    # check game dev folder is under game.repo
    throw new Error "game.client.dev must not be inside game.repo" unless 0 is @paths.client.indexOf @_root
    throw new Error "game.executable.source must not be inside game.repo" unless 0 is @paths.executables.indexOf @_root
    throw new Error "game.image must not be inside game.repo" unless 0 is @paths.images.indexOf @_root

  # Initialize game's git repository to store executables, images and game files
  # 
  # @param callback [Function] initialization end function. Invoked with:
  # @option callback err [String] and error message, or null if no error occured
  # 
  # @overload init(reset, callback)
  #   Init game repo, but removes existing on if reset is true
  #   @param reset [Boolean] true to remove existing repository
  init: (reset, callback) =>
    [callback, reset] = [reset, false] if _.isFunction reset
    return if fromRule module, callback
    
    # in case of current initialization, retry 250ms later
    if @_initInProgress
      return _.delay => 
        @init reset, callback
      , 250

    hasError = (err) =>
      if err
        @_initInProgress = false
        callback err
      return err?

    # enforce folders existence at startup, synchronously!
    try 
      @_initInProgress = true
      # force removal if specified
      if reset and fs.existsSync @_root
        try
          removeSync @_root 
          logger.debug "previous git repository removed..."
        catch err
          @_initInProgress = false
          return callback err

      enforceFolderSync @_root, false, logger
      enforceFolderSync @paths.executables, false, logger
      enforceFolderSync @paths.images, false, logger
      enforceFolderSync @paths.client, false, logger

      finished = (err) =>
        return if hasError err

        # creates also the git repository
        configFile = join @_root, '.git', 'config'
        @repo = git @_root
        @repo.git 'config', {}, ['--file', configFile, 'user.name', @user.name], (err) =>
          return if hasError err
          @repo.git 'config', {}, ['--file', configFile, 'user.email', @user.email], (err) =>
            return if hasError err
            # avoid autocrlf for binary files ?? TODO but why ??
            @repo.git 'config', {}, ['--file', configFile, 'core.autocrlf', 'false'], (err) =>
              return if hasError err
              logger.debug "git repository initialized !"
              @_initInProgress = false
              callback null

      # Performs a 'git init' if git repository do not exists
      unless fs.existsSync join @_root, '.git'
        logger.debug "initialize git repository at #{@_root}..."
        # make repository init not parralelizable, or we'll get git errors while trying to configure user infos
        git.init @_root, finished
      else
        logger.debug "using existing git repository..."
        finished()
    catch err
      hasError err

  # Generate a proper Git author string, that ensure at least lastName and correct email
  #
  # @param player [Player] the concerned author
  # @return the author string.
  getAuthor: (player) ->
    firstName = player.firstName or ''
    lastName = player.lastName or ''
    lastName = player.email unless lastName or firstName
    email = player.email
    email += '@unknown.org' unless -1 isnt email.indexOf '@'
    "#{firstName} #{lastName} <#{email}>"

  # Returns tags for this repository. Just tag names and their corresponding ids
  # The Gift `repo.tags()` is awsomely slow, because it gets full details of tags and their commits
  #
  # @param callback [Function] invokation end function, invoked with
  # @option callback err [String] an error details string, or null if no error occured.
  # @option callback tags [Array] an array of tags (may be empty) containing for each tag an object with `name` and `id` attributes
  tags: (callback) =>
    return if fromRule module, callback
    @repo.git 'show-ref', {tags:true}, (err, stdout, stderr) =>
      # ignore error code 1: means no match
      err = null if err?.code is 1
      return callback "failed to read tags: #{err} #{stderr}" if err?
      tags = []

      # parse output that is commit id followed by tag name, with refs/tags/ prefix
      lines = stdout.split '\n'
      for line in lines
        idx = line.indexOf ' '
        continue if idx is -1
        tags.push 
          name: line.substring(idx+1).replace 'refs/tags/', ''
          id: line.substring 0, idx

      callback null, tags

  # Get commits of a given file, or whole repository.
  # History is an array of object containing:
  # - id [String] commit id
  # - date [Date] commit date
  # - author [String] author name
  # - message [String] commit message
  #
  # First in history means most recent, and a "fake" commit may be present if some modification 
  # are not currently commited, containing null id, author and message.
  #
  # The Gift `repo.commits()` is limited to a certain amount of commits, and gets full details.
  #
  # @param file [String] allows to specify a file on which retrieving commits. Optionnal
  # @param callback [Function] invokation end function, invoked with
  # @option callback err [String] an error details string, or null if no error occured.
  # @option callback history [Array] an array of commits (may be empty) containing for each commit an object
  history: (file, callback) =>
    return if fromRule module, callback
    options = format:'format:"%H %at %aN|%s"'
    fileArg = []
    unless callback?
      callback = file
      file = null
    else
      file = resolve @_root, file
      fileArg.push '--', file.replace(@_root, './').replace(new RegExp('\\\\', 'g'), '/')
      # track renames and removes
      options.follow = true 

    @repo.git 'log', options, fileArg, (err, stdout, stderr) =>
      # ignore error code 1: means no match
      # ignore error code 128: bad revision when repository is empty
      err = null if err?.code is 1 or err?.code is 128
      return callback "failed to read history: #{err} #{stderr}" if err?
      history = []

      # parse output that is commit id followed by tag name, with refs/tags/ prefix
      lines = stdout.split '\n'
      for line in lines
        sep1 = line.indexOf ' '
        sep2 = line.indexOf ' ', sep1+1
        sep3 = line.indexOf '|', sep2+1
        continue unless sep1 isnt -1 and sep2 isnt -1 and sep3 isnt -1
        date = new Date()
        date.setTime Number "#{line.substring sep1+1, sep2}000"
        history.push 
          id: line.substring 0, sep1
          date: date
          author: line.substring sep2+1, sep3
          message: line.substring sep3+1

      # also check if there are pending modification
      @repo.git 'status', {porcelain:true}, fileArg, (err, stdout, stderr) =>
        return callback "failed to read history: #{err} #{stderr}" if err?
        return callback null, history unless stdout.trim().length > 0
        # add fake commit if necessary, with last modification date
        fs.stat (if file then file else @_root), (err, stats) =>
          return callback "failed to read last modification date in history: #{err}" if err?

          history.splice 0, 0,
            id: ''
            date: stats.mtime.setMilliseconds 0
            author: null
            message: null
          
          callback null, history

  # Utility to list all path that have been deleted and could be restored.
  #
  # @param callback [Function] invokation end function, invoked with
  # @option callback err [String] an error details string, or null if no error occured.
  # @option callback restorables [Array] an array of objects (may be empty) containing `path` and `id` attributes
  restorables: (callback) =>
    return if fromRule module, callback
    # git log --diff-filter=D --name-only --pretty=format:"%H"
    @repo.git 'log', {'diff-filter': 'D', 'name-only': true, pretty:'format:"%H"'}, (err, stdout, stderr) =>
      # ignore error code 1: means no match
      # ignore error code 128: bad revision when repository is empty
      err = null if err?.code is 1 or err?.code is 128
      return callback "failed to read restorables: #{err} #{stderr}" if err?
      restorables = []

      # parse output that is commit id followed by multiple lines containing paths
      # an empty line distinguish from next commit
      lines = stdout.split '\n'
      commitId = null
      paths = []

      putInRestorables = =>
        restorables.push id: commitId, path: path for path in paths
        commitId = null
        paths = []

      for line in lines
        if commitId is null
          commitId = line 
        else if line is ''
          # all lines of this commit were found
          putInRestorables()
        else
          paths.push line.replace '"', ''
      putInRestorables()

      # remove multiples occurence of a path and only kept the last one
      restorables = _.uniq restorables, false, (element) -> element.path

      callback null, restorables

  # Retrieves a file to a given version. Content is returned base64 encoded
  #
  # @param file [String] consulted file
  # @param version [String] commit id of the concerned version
  # @param callback [Function] end callback, invoked with two arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback content [String] the base64 encoded content
  readVersion: (file, version, callback) =>
    return if fromRule module, callback
    # item path must be / separated, and relative to repository root
    path = file.replace(@_root, '').replace /\\/g, '\/'
    # show file at specified revision
    @repo.git 'show', {}, "#{version}:.#{path}", (err, stdout, stderr) =>
      return callback "Failed to get version content: #{err}" if err?
      callback null, new Buffer(stdout, 'binary').toString 'base64'

# singleton instance
_instance = undefined
class VersionService
  @get: ->
    _instance ?= new _VersionService()

module.exports = VersionService