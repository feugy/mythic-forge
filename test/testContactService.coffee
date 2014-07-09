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
{expect} = require 'chai'
Mailgun = require 'mailgun-js'
service = require('../hyperion/src/service/ContactService').get()
Player = require '../hyperion/src/model/Player'
{confKey} = require '../hyperion/src/util/common'

describe 'Contact service tests', ->
  
  # given a mailer configured on sandbox
  domain = confKey 'mailgun.domain'
  mailer = new Mailgun apiKey: confKey('mailgun.key'), domain: domain

  # utility poll method, that waits for query to be fullfilled
  pollEvent = (query, end, _number = 0) ->
    # delay before trying, result are not synchronously delivered
    _.delay -> 
      mailer.events().get query, (err, events) =>
        return end err if err?
        return end null, events.items if events.items.length > 0
        pollEvent query, end,
    , 500

  describe 'given players from differents providers', ->

    unic = Math.floor Math.random()*10000

    players = [
      new Player(email: "google.#{unic}@#{domain}", provider: 'Google', firstName: 'Mythic Google', lastName: 'Forge Google')
      new Player(email: "github.#{unic}@#{domain}", provider: 'Github', firstName: 'Mythic Github', lastName: 'Forge Github')
      new Player(email: "twitter.#{unic}@unexisting.com", provider: 'Twitter', firstName: 'Mythic Manual', lastName: 'Forge Twitter')
      new Player(email: "manual.#{unic}", password: 'test', firstName: 'Mythic Manual', lastName: 'Forge Manual')
    ]

    before (done) ->
      async.each players, (player, next) ->
        player.save next
      , done

    after (done) ->
      async.each players, (player, next) ->
        player.remove next
      , done

    it 'should performs replacement within body', (done) ->
      template = _.template 'Yu won !\n<p>Congratulations #{player.firstName} you won the game !</p>', 
        null, 
        service._templateSettings
      
      service._makeMail players[0], template, (err, data) ->
        expect(err).not.to.exist
        expect(data).to.have.property('subject').that.equal 'Yu won !'
        expect(data).to.have.property('html').that.equal "<p>Congratulations #{players[0].firstName} you won the game !</p>"
        done()

    it 'should allow empty subjects', (done) ->
      template = _.template '\n<p>empty subject for #{player.lastName}</p>', 
        null, 
        service._templateSettings
      
      service._makeMail players[1], template, (err, data) ->
        expect(err).not.to.exist
        expect(data).to.have.property('subject').that.equal ''
        expect(data).to.have.property('html').that.equal "<p>empty subject for #{players[1].lastName}</p>"
        done()

    it 'should allow non intentionnal empty subjects', (done) ->
      template = _.template 'empty subject for #{player.email}', 
        null, 
        service._templateSettings
      
      service._makeMail players[2], template, (err, data) ->
        expect(err).not.to.exist
        expect(data).to.have.property('subject').that.equal ''
        expect(data).to.have.property('html').that.equal "empty subject for #{players[2].email}"
        done()

    it 'should failed on empty body', (done) ->
      template = _.template '\t\t\n\t\t', 
        null, 
        service._templateSettings
      
      service._makeMail players[3], template, (err, data) ->
        expect(err).to.have.property('message').that.include 'body cannot be empty'
        done()

    it 'should send message to a single players', (done) ->
      @timeout 15000

      # when sending message to a single players
      service.sendTo players[0], 'Hello #{player.firstName}\nHey #{player.lastName} You won the <b>game</b> !', (err, report) ->
        expect(err).not.to.exist
        expect(report).to.have.lengthOf 1
        expect(report[0]).to.deep.equal
          success: true
          kind: 'email'
          endpoint: players[0].email

        # then mail sending was accepted
        pollEvent recipient: players[0].email, (err, events) ->
          expect(err).not.to.exist
          expect(events).to.have.lengthOf 1
          expect(events[0]).to.have.property('event').that.equal 'accepted'
          done();

    it 'should ignore players that have inexistant or misformated emails', (done) ->
      @timeout 15000

      # when sending message to a single players
      service.sendTo players, 'Hello #{player.firstName}\nMails are a success ! #{player.lastName}', (err, report) ->
        expect(err).not.to.exist
        expect(report).to.have.lengthOf players.length
        async.each players, (player, next) ->
          operation = _.findWhere report, endpoint: player.email
          expect(operation, "#{player.email} has no report").to.exist
          # then unexisting domain are identified
          if player.provider is 'Twitter'
            expect(operation.success, "#{player.email} has sent").to.be.false
            expect(operation.err, "#{player.email} has wrong error").to.have.property('message').that.include 'unexistent domain'
          else if player.provider is null
            # then non email are identified
            expect(operation.success, "#{player.email} has sent").to.be.false
            expect(operation.err, "#{player.email} has wrong error").to.have.property('message').that.include 'invalid email'
          else
            # then correct email where processed
            expect(operation.success, "#{player.email} not been has sent: #{operation.err}").to.be.true
            # then mail sending was accepted
            return pollEvent recipient: player.email, (err, events) ->
              expect(err).not.to.exist
              expect(events).to.have.lengthOf 1
              expect(events[0]).to.have.property('event').that.equal 'accepted'
              next()
          next()
        , done