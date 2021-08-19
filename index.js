#!/usr/bin/env node
require('dotenv').config();
var WebSocketServer = require('websocket').server;
var http = require('http');
var mysql = require('mysql2');

const mysqlconnection = mysql.createConnection({
    host: process.env.MYSQL_HOST,
    user: process.env.MYSQL_USER,
    database: process.env.MYSQL_DATABASE,
    password: process.env.MYSQL_PASSWORD
  });

var server = http.createServer(function(request, response) {
    console.log((new Date()) + ' Received request for ' + request.url);
    response.writeHead(404);
    response.end();
});
server.listen(3000, function() {
    mysqlconnection.query("SET SESSION wait_timeout = 604800"); 
    console.log((new Date()) + ' Server is listening on port 3000');
});

wsServer = new WebSocketServer({
    httpServer: server,
    keepalive: false,
    autoAcceptConnections: false
});


var connections = []

wsServer.on('request', function(request) {
    var connection = request.accept('echo', request.origin);
    console.log((new Date()) + connection.remoteAddress + ' connected.');
    connection.on('message', async function(message) {
        if (message.type === 'utf8') {
            let data = JSON.parse(message.utf8Data)
            if (data.action == 'connect') {
                mysqlconnection.execute(
                    'SELECT * FROM user WHERE serial = ?',
                    [data.serial],
                    function(err, results, fields) {
                        if (results) {
                            connection.sendUTF(JSON.stringify({connection: {
                                isOk: true,
                                id: results[0].id
                            }}))
                            connections[connection.remoteAddress] = results[0]
                        } else {
                            connection.sendUTF(JSON.stringify({connection: {
                                isOk: false
                            }}))
                        }
                    }
                  );
            }
            if (data.action == 'testconn') {
                connection.sendUTF(JSON.stringify({testconn: {
                    isOk: true
                }}))
            }
            if (data.action == 'getonline') {
                let nicks = []
                let playersRemoteIP = Object.keys(connections)
                playersRemoteIP.forEach(element => {
                    nicks.push(connections[element].nick)
                });
                connection.sendUTF(JSON.stringify({online: nicks}))
            }
        }
    });
    connection.on('close', function(reasonCode, description) {
        console.log((new Date()) + ' Peer ' + connection.remoteAddress + ' disconnected.');
    });
});
