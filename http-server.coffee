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
        default: 60000
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
nodeStatic = require "node-static"
path = require "path"


staticServer = new nodeStatic.Server(args.directory, {cache: false})


class FileSender
    constructor: (file, request, response, timeout) ->
        @sending = false
        @file = file
        @realfile = path.resolve(path.join(args.directory, "." + @file))
        @basename = path.basename file
        @request = request
        @response = response
        @timeout = setTimeout @timeoutExpired.bind(this), timeout
        request.connection.on "close", @close.bind(this)
        request.connection.setMaxListeners(20)
        @watcher = null
        try
            @watcher = fs.watch(path.dirname(@realfile), @fileChanged.bind(this))
        catch e
            response.writeHead(500, {"Content-Type": "text/plain"})
            response.end("Error occurred: " + e)
            @close()
        @fileChanged()

    fileChanged: (event, changedFile) ->
        if @sending or (changedFile is not null and changedFile != @basename)
            return
        fs.exists @realfile, ((exists) ->
            if @sending or not exists
                return
            @sending = true
            staticServer.serveFile(@file, 200, {}, @request, @response)
            @close()
        ).bind(this)

    timeoutExpired: ->
        if not @sending
            @fileChanged()
        if not @sending
            @sending = true
            msg = "Timeout expired for " + @file
            console.log("Timeout expired for " + @file)
            @response.writeHead 404, {"Content-Type": "text/plain"}
            @response.end("Timeout expired for " + @file)
        @close()

    close: ->
        if not @sending
            console.log("Request for " + @file + " closed by client")
        clearTimeout(@timeout)
        if @watcher
            @watcher.close()


http.createServer((request, response) ->
    console.log("Requesting " + request.url + " " + (request.headers["range"] or ""))
    if request.url[0] != "/" or request.url.indexOf("..") > -1
        response.writeHead(403, {"Content-Type": "text/plain"})
        response.end("Nope")
    else
        if not args.require_header
            timeout = args.timeout
        if "timeout" in request.headers
            timeout = request.headers["timeout"]
            if timeout > args.timeout
                timeout = args.timeout
        if timeout < 0
            timeout = 0

        requestedFile = request.url
        if requestedFile.slice(-1) == "/"
            requestedFile += "index.html"
        new FileSender(requestedFile, request, response, args.timeout)
).listen(args.port)
