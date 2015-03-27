#!/usr/bin/env coffee
yargs = require("yargs")
express = require "express"
fs = require "fs"
morgan = require "morgan"
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


timeoutHandler = (root, options) ->
    if not "maxTimeout" in options
        options["maxTimeout"] = 60000
    if not "requireHeader" in options
        options["requireHeader"] = true

    return (req, res, next) ->
        file = path.join(root, "./" + req.url)

        # Don't bother watching files outside of the directory
        if file.indexOf(root) != 0
            return next()

        if req.url[req.url.length - 1] == "/"
            file = path.join(file, "index.html")

        fs.exists file, (exists) ->
            if exists
                return next()

            timeout = 0
            if "timeout" in req.headers
                timeout = Math.min(options["maxTimeout"], req.headers["timeout"])
            else if not options["requireHeader"]
                timeout = options["maxTimeout"]
            if timeout <= 0
                return next()

            watcher = null
            timer = null
            done = ->
                if watcher
                    watcher.close()
                clearTimeout(timer)
                next()
            try
                watcher = fs.watch(path.dirname(file), (event, changedFile) ->
                    if changedFile != path.basename(file)
                        return
                    done()
                )
                timer = setTimeout((->
                    done()
                ), timeout)
            catch err
                done()


app = express()
app.use(morgan(":method :url served :status in :response-time ms"))
app.use(timeoutHandler(args.directory, {maxTimeout: args.timeout, requireHeader: args.requireHeader}))
app.use(express.static(args.directory))
app.listen(args.port)
