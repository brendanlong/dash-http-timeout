#!/usr/bin/env coffee
args = require("yargs")
    .alias("i", "input")
    .alias("o", "output")
    .alias("h", "help")
    .argv
async = require "async"
childProcess = require "child_process"
dateFormat = require "dateformat"
fs = require "fs"
http = require "http"
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


if args.help or not args.input or not args.output
    console.log("Usage:", process.argv[0], "--input [input file] --output [output directory]")
    process.exit(1)

# Create output directory
try
    if not fs.statSync(args.output).isDirectory()
        console.log("Output directory", args.output, "is a file.")
        process.exit(1)
catch error
    fs.mkdirSync(args.output)


# Start writing segments with FFMPEG
segmentDuration = 5
ffmpeg = childProcess.spawn("ffmpeg", ["-re", "-i", args.input, "-y", "-loglevel", "-16", \
    "-s", "1280x720", "-c:v", "libx264", "-preset", "fast", "-force_key_frames", "expr:gte(t,n_forced*" + segmentDuration + ")", "-c:a", "aac", "-strict", "-2", "-ab", "128k", "-ar", "44100", "-f", "ssegment", "-segment_time", segmentDuration, "-segment_time_delta", "0.05", args.output + "/segment-%d.720p.mp4"])
ffmpegFdPath = "/proc/" + ffmpeg.pid + "/fd"
ffmpeg.stdout.on "data", (data) -> console.log("stdout:" + data)
ffmpeg.stderr.on "data", (data) -> console.log("stderr:" + data)
        

# Check if a file is open in FFMPEG
# This would be way easier if we could use inotify, but it's currently broken
# in modern versions of Node.js
isOpenInFFMPEG = (file, callback) ->
    fs.readdir ffmpegFdPath, (err, files) ->
        if err
            console.log("Failed to read " + ffmpegFdPath + ": " + err)
            callback false
        fullPaths = files.map((current) -> return ffmpegFdPath + "/" + current)
        async.map fullPaths, fs.readlink, (err, results) ->
            if err
                console.log("Failed to read links: " + err)
                callback false
            callback results.includes file


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
        basename = path.basename @file
        if changedFile != basename
            return
        file = @file
        response = @response
        saveThis = this
        fs.exists file, (exists) ->
            if not exists
                return
            isOpenInFFMPEG file, (isOpen) ->
                if isOpen
                    return
                fs.readFile file, (err, data) ->
                    if err
                        response.writeHead 500
                        response.end("Error reading " + file + ": " + err)
                        saveThis.close()
                        return
                    if file.endsWith(".mp4")
                        contentType = "video/mp4"
                    else
                        contentType = "application/octet-stream"
                    response.writeHead(200, {"Content-Type": contentType})
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
    requestedFile = path.resolve "." + request.url
    console.log("Requesting " + requestedFile)
    if request.url == "/"
        response.writeHead(200, {"Content-Type": "application/dash+xml"})
        response.end('<?xml version="1.0"?><MPD xmlns="urn:mpeg:dash:schema:mpd:2011" profiles="urn:mpeg:dash:profile:full:2011" minBufferTime="PT1.5S" type="dynamic" minimumUpdatePeriod="PT5S" availabilityStartTime="' + dateFormat(start, "isoUtcDateTime") + '"><Period id="1"><AdaptationSet mimeType="video/mp4"><BaseURL>test/</BaseURL><Representation id="720p" bandwidth="3200000" width="1280" height="720"><SegmentTemplate media="segment-$Number$.$RepresentationID$.mp4" duration="' + segmentDuration + '"/></Representation></AdaptationSet></Period></MPD>')
    else if request.url[0] != "/" or request.url.contains("..")
        response.writeHead(404, {"Content-Type": "text/plain"})
        response.end("Does not exist")
    else
        new FileSender(requestedFile, response, segmentDuration * 2000).fileChanged(null, path.basename requestedFile)
).listen("8081")
