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

_ = require 'underscore'
async = require 'async'
{join, sep} = require 'path'
moment = require 'moment'
FieldType = require '../hyperion/src/model/FieldType'
utils = require '../hyperion/src/util/common'
ruleUtils = require '../hyperion/src/util/rule'
Player = require '../hyperion/src/model/Player'
ContactService = require('../hyperion/src/service/ContactService').get()
{expect} = require 'chai'

describe 'Utilities tests', -> 

  it 'should path aside to another one be made relative to each other', ->
    a = join 'folder1', 'folder2', 'compiled', 'rule'
    b = join 'folder1', 'folder2', 'lib'
    expect(utils.relativePath a, b).to.equal join '..', '..', 'lib'

  it 'should path above another one be made relative to each other', ->
    a = join 'folder1', 'folder2', 'lib', 'compiled', 'rule'
    b = join 'folder1', 'folder2', 'lib'
    expect(utils.relativePath a, b).to.equal join '..', '..'

  it 'should path under another one be made relative to each other', ->
    a = join 'folder1', 'folder2', 'lib'
    b = join 'folder1', 'folder2', 'lib', 'compiled', 'rule'
    expect(utils.relativePath a, b).to.equal ".#{sep}#{join 'compiled', 'rule'}"

  it 'should paths of another drive be made relative to each other', ->
    a = join 'folder1', 'folder2', 'lib'
    b = join 'root', 'lib'
    expect(utils.relativePath a, b).to.equal join '..', '..', '..', 'root', 'lib'

  it 'should fixed-length token be generated', -> 
    # when generating tokens with fixed length, then length must be compliant
    expect(utils.generateToken 10).to.have.lengthOf 10
    expect(utils.generateToken 0).to.have.lengthOf 0
    expect(utils.generateToken 4).to.have.lengthOf 4
    expect(utils.generateToken 20).to.have.lengthOf 20
    expect(utils.generateToken 100).to.have.lengthOf 100

  it 'should token be generated with only alphabetical character', -> 
    # when generating a token
    token = utils.generateToken 1000
    # then all character are within correct range
    for char in token
      char = char.toUpperCase()
      code = char.charCodeAt 0
      expect(code).to.be.at.least(40).and.at.most 90
      expect(code).to.satisfy (n) => n <= 58 or n >= 64

  it 'should plainObjects keep empty objects', ->
    tree = 
      subObj: 
        empty: {}
        emptyArray: []
      subArray: [
        {},
        []
      ]
    # when transforming into plain objects
    result = utils.plainObjects tree

    # then all empty properties are still here
    expect(result.subObj.empty).to.be.an.instanceof(Object).and.to.be.empty
    expect(result.subObj.emptyArray).to.be.an.instanceof(Array).and.to.have.lengthOf 0
    expect(result.subArray).to.be.an.instanceof(Array).and.to.have.lengthOf 2
    expect(result.subArray).deep.equal [{}, []]

  describe 'given a mocked ContactService', ->
    original = ContactService.sendTo
    sendToArgs = []
    sendToErr = []
    sendToReport = []
    invoke = 0
    unic = Math.floor Math.random()*10000

    players = [
      new Player(email: "google@#{unic}.com", provider: 'Google', firstName: 'Google', lastName: 'Forge Google')
      new Player(email: "github@#{}{unic}.com", provider: 'Github', firstName: 'Github', lastName: 'Forge Github')
      new Player(email: "twitter@#{unic}.com", provider: 'Twitter', firstName: 'Twitter', lastName: 'Forge Twitter')
    ]

    before (done) ->
      ContactService.sendTo = (args..., callback) ->
        sendToArgs.push args
        callback sendToErr[invoke], sendToReport[invoke++]

      async.each players, (player, next) ->
        player.save next
      , done

    beforeEach ->
      invoke = 0
      sendToArgs = []
      sendToErr = []
      sendToReport = []

    after (done) ->
      ContactService.sendTo = original
      async.each players, (player, next) ->
        player.remove next
      , done

    it 'should fail on campaign without players', (done) ->
      # when sending notification to a single player
      ruleUtils.notifCampaigns msg: 'Hey #{player.email}', (err) ->
        expect(err).to.have.property('message').that.include "campaign must be an object with 'msg' and 'players' properties"
        done()

    it 'should fail on campaign without msgs', (done) ->
      # when sending notification to a single player
      ruleUtils.notifCampaigns players: players, msg: undefined, (err) ->
        expect(err).to.have.property('message').that.include "campaign must be an object with 'msg' and 'players' properties"
        done()

    it 'should send notification for single campaign', (done) ->
      sendToReport.push [success: true, kind: 'email', endpoint: players[0].email]

      # when sending notification to a single player
      ruleUtils.notifCampaigns players: players[0], msg: 'Hey #{player.email}', (err, report) ->
        expect(err).not.to.exist
        expect(invoke).to.equal 1
        # then expect ContactService.sendTo arguments where generated
        expect(sendToArgs[0]).to.have.lengthOf 2
        expect(sendToArgs[0][0]).to.deep.equal players[0]
        expect(sendToArgs[0][1]).to.equal 'Hey #{player.email}'
        expect(report).to.deep.equal sendToReport[0]
        done()

    it 'should send notification for multiple campaigns', (done) ->
      sendToReport.push [
        {success: true, kind: 'email', endpoint: players[0].email}
        {success: true, kind: 'email', endpoint: players[1].email}
      ], [
        {success: true, kind: 'email', endpoint: players[2].email}
      ]
      msg1 = 'Hey #{player.email}'
      msg2 = 'Yo #{player.firstName}'

      # when sending notification to a single player
      ruleUtils.notifCampaigns [
        {players: players[0..1], msg: msg1 }
        {players: players[2], msg: msg2}
      ], (err, report) ->
        expect(err).not.to.exist
        expect(invoke).to.equal 2
        # then expect ContactService.sendTo arguments where generated
        expect(sendToArgs[0]).to.have.lengthOf 2
        expect(sendToArgs[0][0]).to.deep.equal players[0..1]
        expect(sendToArgs[0][1]).to.equal msg1
        expect(sendToArgs[1]).to.have.lengthOf 2
        expect(sendToArgs[1][0]).to.deep.equal players[2]
        expect(sendToArgs[1][1]).to.equal msg2
        expect(report).to.deep.equal _.flatten sendToReport
        done()

  describe 'given timer configured every seconds', ->
    @timeout 4000

    it 'should time event be fired any seconds', (done) ->
      events = []
      now = null
      saveTick = (tick) -> 
        now = moment() unless now?
        events.push tick

      _.delay =>
        ruleUtils.timer.removeListener 'change', saveTick

        expect(events.length).to.be.at.least 3
        expect(events[0].seconds()).to.equal now.seconds()
        expect(events[1].seconds()).to.equal (now.seconds()+1)%60
        expect(events[2].seconds()).to.equal (now.seconds()+2)%60
        done()
      , 3100
      ruleUtils.timer.on 'change', saveTick

    it 'should timer be stopped', (done) ->
      events = []
      now = moment()
      stop = null
      saveTick = (tick) -> 
        stop = moment()
        events.push tick
        ruleUtils.timer.stopped = true

      _.delay =>
        ruleUtils.timer.removeListener 'change', saveTick

        expect(events).to.have.lengthOf 1
        expect(events[0].seconds()).to.equal (now.seconds()+1)%60
        expect(stop.diff events[0]).to.be.closeTo 0, 999
        done()
      , 2100
      ruleUtils.timer.on 'change', saveTick

    it 'should timer be modified and restarted', (done) ->
      events = []
      future = moment().add 'y', 1
      saveTick = (tick) -> events.push tick
      
      _.delay ->
        ruleUtils.timer.set future
        ruleUtils.timer.stopped = false
      , 1100
      ruleUtils.timer.on 'change', saveTick

      _.delay =>
        ruleUtils.timer.removeListener 'change', saveTick

        expect(events).to.have.lengthOf 2
        expect(events[0].seconds()).to.equal (future.seconds()+1)%60
        expect(events[0].year()).to.equal moment().year() + 1
        expect(events[1].seconds()).to.equal (future.seconds()+2)%60
        done()
      , 3100

  describe 'given a clean model cache', ->

    beforeEach (done) ->
      # empty field types.
      FieldType.collection.drop -> FieldType.loadIdCache done

    it 'should be loaded into cache at creation', (done) ->
      now = moment()
      type = new FieldType id:'montain'
      type.save (err) ->
        return done err if err?
        expect(moment(FieldType.cachedSince 'montain').diff now).closeTo 0, 50
        done()

    it 'should cache since be refreshed at update', (done) ->
      now = moment()
      type = new FieldType id:'montain'
      type.save (err, type) ->
        return done err if err?
        _.delay ->
          type.descImage = 'toto.png'
          save = moment()
          type.save (err) ->
            return done err if err?
            expect(save.diff now).to.be.at.least 100
            expect(moment(FieldType.cachedSince 'montain').diff save).to.be.closeTo 0, 50
            done()
        , 100

    it 'should cache be cleared at deletion', (done) ->
      type = new FieldType id:'montain'
      type.save (err, type) ->
        return done err if err?
        _.delay ->
          type.remove (err) ->
            return done err if err?
            expect(FieldType.cachedSince('montain')).to.equal 0
            done()
        , 100
      
    it 'should cache be evicted after a while', (done) ->
      @timeout 1000
      type = new FieldType id:'montain'
      type.save (err, type) ->
        return done err if err?
        _.delay ->
          return done err if err?
          expect(FieldType.cachedSince('montain')).to.equal 0
          done()
        , 700