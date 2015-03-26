#!/usr/bin/env coffee
args = require("yargs")
    .usage("Usage: $0 [options]")
    .option("d",
        alias: "directory"
        demand: true
        describe: "The directory to server (this directory will become / in
            the HTTP server"
        requiresArg: true
        type: "string"
    )
    .help("h").alias("h", "help")
    .option("p",
        alias: "port"
        default: 8081
        describe: "The HTTP server port."
        requiresArg: true
    )
    .option("t",
        alias: "timeout"
        default: 10000
        describe: "The maximum timeout to apply (and the default timeout if
            --require-header is not set)."
        requireArg: true
    )
    .option("require-header",
        describe: "Require the Timeout header to be sent by a client to apply
            timeout logic. By default, the server applies the default timeout
            to all requests (to make it easier to test against unmodified
            clients), but this is probably a bad idea in most cases."
        type: "boolean"
    )
    .epilog("By Brendan Long <b.long@cablelabs.com> at CableLabs, Inc.")
    .argv
fs = require "fs"
http = require "http"
mime = require "mime"
path = require "path"


mime.define(
    "application/dash+xml": ["mpd"]
)


class FileSender
    constructor: (file, response, timeout) ->
        @sent = false
        @file = path.resolve file
        @response = response
        @timeout = setTimeout @timeoutExpired.bind(this), timeout
        @watcher = null
        try
            @watcher = fs.watch(path.dirname(file), @fileChanged.bind(this))
        catch e
            response.writeHead(500, {"Content-Type": "text/plain"})
            response.end("Error occurred: " + e)
            @close()

    fileChanged: (event, changedFile) ->
        if changedFile is not null and changedFile != path.basename(@file)
            return
        file = @file
        response = @response
        saveThis = this
        fs.exists file, (exists) ->
            if not exists
                return
            fs.readFile file, (err, data) ->
                if err
                    response.writeHead 500, {"Content-Type": "text/plain"}
                    response.end("Error reading " + file + ": " + err)
                    saveThis.close()
                    return
                console.log("Sending " + path.basename(file))
                response.writeHead(200, {"Content-Type": mime.lookup(file)})
                response.end(data)
                saveThis.close()

    timeoutExpired: ->
        if not @sent
            @fileChanged()
        if not @sent
            @response.writeHead(404, {"Content-Type": "text/plain"})
            @response.end("Timeout expired and " + @file + " still doesn't exist.")
        @close()

    close: ->
        @sent = true
        clearTimeout(@timeout)
        if @watcher
            @watcher.close()

# HTTP Server
start = Date.now() + 10
http.createServer((request, response) ->
    console.log("Requesting " + request.url)
    if request.url[0] != "/" or request.url.indexOf("..") > -1
        response.writeHead(403, {"Content-Type": "text/plain"})
        response.end("Nope")
    else
        requestedFile = path.join ".", args.directory, request.url
        if requestedFile.slice(-1) == "/"
            requestedFile += "index.html"
        requestedFile = path.resolve requestedFile
        new FileSender(requestedFile, response, args.timeout).fileChanged()
).listen(args.port)
