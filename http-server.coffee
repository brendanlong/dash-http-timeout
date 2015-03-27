#!/usr/bin/env coffee
yargs = require("yargs")
express = require "express"
fs = require "fs"
path = require "path"


args = yargs
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


app = express()
app.use(express.static(args.directory))
app.use((req, res, next) ->
    # TODO: Use Express static's handling to figure out real path?
    file = path.join(args.directory, "." + req.url)
    if req.url[req.url.length - 1] == "/"
        file = path.join(file, "index.html")

    timeout = 0
    if "timeout" in req.headers
        timeout = Math.min(args.timeout, req.headers["timeout"])
    else if not args.requireHeader
        timeout = args.timeout
    if timeout <= 0
        return next()

    basename = path.basename file
    watcher = null
    timer = null
    done = ->
        if watcher
            watcher.close()
        clearTimeout(timer)
        next()
    try
        watcher = fs.watch(path.dirname(file), (event, changedFile) ->
            if changedFile != basename
                return
            console.log("File " + file + " appeared!")
            done()
        )
        timer = setTimeout((->
            console.log("Timeout for " + file + " expired!")
            done()
        ), timeout)
    catch err
        done()
)
app.use(express.static(args.directory))
app.listen(args.port)
