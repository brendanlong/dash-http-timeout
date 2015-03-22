#!/usr/bin/env coffee
args = require("yargs")
    .alias("i", "input")
    .alias("o", "output")
    .alias("h", "help")
    .argv
childProcess = require "child_process"
dateFormat = require "dateformat"
fs = require "fs"
http2 = require "http2"

if args.help or not args.input or not args.output
    console.log("Usage:", process.argv[0], "--input [input file] --output [output directory]")
    process.exit(1)

try
    if not fs.statSync(args.output).isDirectory()
        console.log("Output directory", args.output, "is a file.")
        process.exit(1)
catch error
    fs.mkdirSync(args.output)

fs.watch(args.output, (event, filename) ->
    console.log(filename, event)
)

segmentDuration = 5
p = childProcess.spawn("ffmpeg", ["-re", "-i", args.input, "-y", "-loglevel", "-16", \
    "-s", "1280x720", "-c:v", "libx264", "-preset", "fast", "-force_key_frames", "expr:gte(t,n_forced*" + segmentDuration + ")", "-c:a", "aac", "-strict", "-2", "-ab", "128k", "-ar", "44100", "-f", "ssegment", "-segment_time", segmentDuration, "-segment_time_delta", "0.05", args.output + "/segment-%d.720p.ts"])
p.stdout.on "data", (data) -> console.log("stdout:" + data)
p.stderr.on "data", (data) -> console.log("stderr:" + data)

start = Date.now()
options =
    "key": fs.readFileSync("test-server.key", "utf8")
    "cert": fs.readFileSync("test-server.cert", "utf8")
http2.createServer(options, (request, response) ->
    response.writeHead(200)
    response.end('<?xml version="1.0"?><MPD xmlns="urn:mpeg:dash:schema:mpd:2011" profiles="urn:mpeg:dash:profile:full:2011" minBufferTime="PT1.5S" type="dynamic" minimumUpdatePeriod="PT5S" availabilityStartTime="' + dateFormat(start, "yyyy-mm-dd'T'HH:MM:ss") + '"><Period id="1"><AdaptationSet mimeType="video/mp2t"><BaseURL>test/</BaseURL><Representation id="720p" bandwidth="3200000" width="1280" height="720"><SegmentTemplate media="segment-%d.ts" timescale="90000" duration="' + segmentDuration * 90000 + '"/></Representation></AdaptationSet></Period></MPD>')
).listen("8081")
