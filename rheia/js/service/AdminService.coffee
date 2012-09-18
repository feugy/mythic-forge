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

define [
  'backbone'
  'model/sockets'
], (Backbone, sockets) ->

  # The administration service is wired to server features not related to a model.
  # For example, it triggers game client deployement
  # Extends Backbone.Events to trigger events: each moethod will publish an event (same name as method)
  # when finished.
  #
  # Instanciated as a singleton in `rheia.adminService` by the Router
  class AdminService
    _.extend @prototype, Backbone.Events

    # **private**
    # Current deployement state. Contains:
    # @option version [String] current version, or null if no version 
    # @option deployed [String] name of the deployed version, null if ne pending deployement 
    # @option author [String] email of the deployer
    # @option inProgress [Boolean] true if deployement still in progress    _state: null
    _state: null

    # Service constructor
    constructor: ->
      # first, ask for deployement state
      sockets.admin.emit 'deployementState'
      sockets.admin.on 'deployement', @_onDeployementState

      sockets.admin.on 'deployementState-resp',  (err, state) =>
        return rheia.router.trigger 'serverError', err, method:"AdminService.deployementState" if err?
        @_state = state
        @trigger 'state'

      sockets.admin.on 'listVersions-resp', (err, versions) =>
        rheia.router.trigger 'serverError', err, method:"AdminService.versions" if err?
        @trigger 'versions', err, versions, @_version

      sockets.admin.on 'deploy-resp', (err) =>
        rheia.router.trigger 'serverError', err, method:"AdminService.deploy" if err?
        @trigger 'deploy', err

      sockets.admin.on 'commit-resp', (err) =>
        rheia.router.trigger 'serverError', err, method:"AdminService.commit" if err?
        @trigger 'commit', err

      sockets.admin.on 'rollback-resp', (err) =>
        rheia.router.trigger 'serverError', err, method:"AdminService.rollback" if err?
        @trigger 'rollback', err

    # Simple getter that indicate if a version is currently deploying
    # @return true if there is a deployement in progress
    isDeploying: =>
      @_state?.deploying

    # Simple getter that indicate if a deployement is ready for commit or rollback
    # @return true if there is a deployement in progress
    hasDeployed: =>
      @_state?.deployed?

    # Simple getter that indicate if the current version deployer is the connected player
    # @return true if there is a deployement in progress, and the deployer is the current player
    isDeployer: =>
      @_state?.deployed? and @_state?.deployer is rheia?.player?.email

    # Ask on the server the list of game client versions.
    # Once retrieved, results are publish on the `gameVersions` router event.
    versions: =>
      sockets.admin.emit 'listVersions'

    # Ask server to deploy new version.
    # During deployement, messages relative to deployement status will be issued and relayed 
    # with 'progress' event
    #
    # @param version [String] the new version name.
    deploy: (version) =>
      console.info "deploy new version #{version}"
      sockets.admin.emit 'deploy', version

    # Ask server to commit current deployement.
    # During commit, messages relative to deployement status will be issued and relayed 
    # with 'progress' event
    commit: (version) =>
      console.info "commit current deployement"
      sockets.admin.emit 'commit'

    # Ask server to commit current deployement.
    # During commit, messages relative to deployement status will be issued and relayed 
    # with 'progress' event
    rollback: (version) =>
      console.info "rollback current deployement"
      sockets.admin.emit 'rollback'

    # **private**
    # Deployement state handler.
    #
    # @param state [String] current deployement state
    # @param step [Number] current step in deployement
    _onDeployementState: (state, step) =>
      console.info "deployement: #{state} - #{step}"
      @trigger 'progress', state, step