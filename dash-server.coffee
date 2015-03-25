#!/usr/bin/env coffee
args = require("yargs")
    .alias("d", "directory")
    .alias("h", "help")
    .argv
async = require "async"
fs = require "fs"
http = require "http"
mime = require "mime"
path = require "path"


String.prototype.endsWith = (suffix) ->
    return this.indexOf(suffix, this.length - suffix.length) != -1

String.prototype.contains = (s) ->
    return this.indexOf(s) != -1

Array.prototype.includes = (v) ->
    for i in this
        if i == v
            return true
    return false


mime.define(
    "application/dash+xml": ["mpd"]
)


if args.help or not args.directory
    console.log("Usage:", process.argv[0], "--directory [directory to serve]")
    process.exit(1)

# Create output directory if it doesn't exist
try
    if not fs.statSync(args.directory).isDirectory()
        console.log("Output directory", args.directory, "is a file.")
        process.exit(1)
catch error
    fs.mkdirSync(args.directory)


class FileSender
    constructor: (file, response, timeout) ->
        @sent = false
        @file = path.resolve file
        @response = response
        @timeout = setTimeout @timeoutExpired.bind(this), timeout
        @watcher = null
        try
            directory = path.dirname file
            @watcher = fs.watch directory, @fileChanged.bind(this)
        catch e
            response.writeHead(500, {"Content-Type": "text/plain"})
            response.end("Error occurred: " + e)
            @close()

    fileChanged: (event, changedFile) ->
        if changedFile is not null
            basename = path.basename @file
            if changedFile != basename
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
                response.writeHead(200, {"Content-Type": mime.lookup file})
                response.end(data)
                saveThis.close()

    timeoutExpired: ->
        if not @sent
            this.fileChanged()
        if not @sent
            @response.writeHead(404, {"Content-Type": "text/plain"})
            @response.end("Timeout expired and " + @file + " still doesn't exist.")
        this.close()

    close: ->
        @sent = true
        clearTimeout(@timeout)
        if @watcher
            @watcher.close()

# HTTP Server
start = Date.now() + 10
http.createServer((request, response) ->
    console.log("Requesting " + request.url)
    if request.url[0] != "/" or request.url.contains ".."
        response.writeHead(403, {"Content-Type": "text/plain"})
        response.end("Nope")
    else
        requestedFile = path.join ".", args.directory, request.url
        if requestedFile.endsWith "/"
            requestedFile += "index.html"
        requestedFile = path.resolve requestedFile
        new FileSender(requestedFile, response, 10000).fileChanged()
).listen("8081")
