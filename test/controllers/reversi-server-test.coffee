
app = require('../../app')
revServer = app.revServer

ReversiServer = require('../../controllers/reversi-server')
Reversi = require('../../controllers/reversi')
io = require('socket.io-client')
should = require('should')
request = require('superagent')

options =
  transports: ['websocket']
  'force new connection': true

socketURL = 'http://localhost:3000'

gameStandby = (roomName, callback) ->
  clients = new Array(2)

  clients[0] = io.connect(socketURL, options)
  clients[0].on 'connect', ->
    clients[1] = io.connect(socketURL, options)
    clients[1].on 'connect', ->

      clients[0].on 'game standby', ->
        clients[1].on 'game standby', ->
          callback(clients)

      for i in [0..1]
        clients[i].emit('room login', roomName)

turnPlayer = (room, clients) ->
  tp = room.turnPlayer()
  for i in [0..clients.length - 1]
    if clients[i].socket.sessionid == tp
      return clients[i]
  return null

notTurnPlayer = (room, clients) ->
  tp = room.turnPlayer()
  for i in [0..clients.length - 1]
    if clients[i].socket.sessionid != tp
      return clients[i]
  return null

describe 'ReversiServer', ->
  it 'connect', (done) ->
    client = io.connect(socketURL, options)

    client.on 'connect', ->
      sid = @socket.sessionid

      revServer._userStates[sid].state.should.equal('waiting')
      client.disconnect()
      done()

  it 'login (create room and response)', (done) ->
    client = io.connect(socketURL, options)
    roomName = 'testroom'

    client.on 'connect', ->
      sid = @socket.sessionid

      client.on 'loginRoomMsg', (msg) ->
        msg.should.equal(roomName)

        revServer._userStates[sid].state.
          should.equal('login')

        revServer._userStates[sid].roomname.
          should.equal(roomName)

        revServer._roomList[roomName].should.exist
          
        client.disconnect()
        done()

      client.emit 'room login', roomName


  it 'logout (delete room and repsonse)', (done) ->
    client = io.connect(socketURL, options)
    roomName = 'testroom'

    client.on 'connect', ->
      sid = @socket.sessionid

      client.on 'loginRoomMsg', (msg) ->
        console.log "login correct: #{msg}"
        client.emit 'room logout', msg 

      client.on 'logoutRoomMsg', (msg) ->
        msg.should.equal(roomName)

        revServer._userStates[sid].state.
          should.equal('waiting')

        revServer._roomList[roomName].should.not.exist

        console.log "logout correct: #{msg}"
        client.disconnect()
        done()

      client.emit 'room login', roomName

  it 'startGame', (done) ->
    clients = new Array(3)
    roomName = 'testroom'
    sids = new Array(3)
    gameStates = [false, false, false]
    
    checker = (idx) ->
      clients[idx].on 'game standby', ->
        gameStates[idx] = true

        if gameStates[0] = true && gameStates[1] = true
          clients[2].emit('room login')

      if idx == 0
        setTimeout(doneCheck, 1800)
      
    doneCheck = () ->
      gameStates[0].should.equal(true)
      gameStates[1].should.equal(true)
      gameStates[2].should.equal(false)
      for i in [0..2]
        clients[i].disconnect()
      done()

    clients[0] = io.connect(socketURL, options)
    clients[0].on 'connect', ->
      sids[0] = @socket.sessionid
      checker(0)

      clients[1] = io.connect(socketURL, options)
      clients[1].on 'connect', ->
        sids[1] = @socket.sessionid
        checker(1)

        clients[2] = io.connect(socketURL, options)
        clients[2].on 'connect', ->
          sids[2] = @socket.sessionid
          checker(2)

          clients[0].emit('room login', roomName)
          clients[1].emit('room login', roomName)

  it 'put Stone', (done) ->
    roomName = 'testroom2'
    gameStandby roomName, (clients) ->
      room = revServer._roomList[roomName]
      count = 0

      tp = turnPlayer(room, clients)

      clients.forEach (e) ->
        e.on 'game board update', (res) ->
          res.point.x.should.equal(3)
          res.point.y.should.equal(4)
          res.color.should.equal(Reversi.black)
          res.revPoints[0].x.should.equal(4)
          res.revPoints[0].y.should.equal(4)
          if count++ == 1
            done()

      tp.emit 'game board put', {x: 3, y: 4}

      

      
