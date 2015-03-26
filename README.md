# HTTP Timeout DASH Example

This example demonstrates a way to stream DASH segments with no HTTP-round-trip latency, using standard HTTP GET requests and HTTP/1.1.

There is [a screencast demonstrating it on YouTube](https://www.youtube.com/watch?v=YUcfNzPaqf0).

## How it Works

The HTTP server (http-server.coffee) is a normal HTTP server, except that if a client requests a file that doesn't exist, instead of immediately returning a 404 response, it watches for the file to appear until its timeout expires. As soon as the file appears, it sends the response. If the file doesn't appear within the timeout, the server sends a 404 like usual.

## Setup

**Note: This relies on Node.js's `fs.watch` function, which may not work properly on all platforms. It has been tested and works on Linux (Fedora 21) and OS X.**

Install Git, CoffeeScript, Node.js, NPM, Python 3, and [Google Chrome](https://www.google.com/chrome/browser/desktop/) (or some other browser that supports MSE, h.264 and AAC). This should work on Safari but currently doesn't and it's not clear to me why.

Fedora 21:

    sudo yum install coffee-script git nodejs npm python3

Ubuntu:

    sudo apt-get install coffeescript git nodejs npm python3

OS X (with [Homebrew](http://brew.sh/):

    # If you already have Node.js installed, make sure to run `brew update && brew upgrade`
    # because Node.js 0.10.20  has a fatal bug with fs.watch, but it's fixed in 0.10.21
    # If you see, "Bus Error: 10", that's what the problem is.
    brew install git node python3
    npm install -g coffee-script

Clone this repo and navigate to it:

    git clone https://github.com/brendanlong/dash-http-timeout.git
    cd dash-http-timeout

Now install dependencies with `npm`:

    npm install

## Running

Start the HTTP server:

    ./http-server.coffee -d static

In another terminal, start generating segments with a short delay:

    ./generate_segments.py -i static/segments-in -o static/live --startup-delay 10 -v

(Run either command with `--help` to list all options)

Now within 10 seconds, open this URL in Google Chrome:

    http://localhost:8081

(The port is configurable with `--port`)

If you have the terminal and Chrome both on the screen the same time, you can see that playback starts the exact moment when the first segment appears on the filesystem, and because DASH.js doesn't buffer correctly in this case, and copying the files takes time, there might be slight stutters before files become available. The stuttering could be fixed a tiny buffer (time to copy file + 1/2 RTT).

If you want to replay this example, just re-run the `generate_segments.py` command and refresh the page in Google Chrome. `generate_segments.py` will need confirmation before deleting the static/live directory, since deleting folders without asking tends to be a bad idea. See `./generate_segments.py --help` for more options (in case you want to delete that directory without asking, or if you want to use a different example stream).

If you want to play the MPD directly, it's at "/live/lifting-off.mpd".

## Caviats

`generate_segments.py` is a script which imitates a live DASH segmenter by copying files from one directory to another. When run, it immediately copies the MPD and initialization segments, optionally waits for a given delay, and then copies segment files in order, sleeping for their duration between copies. Ideally, this example would use a real segmenter, but FFMPEG can't create DASH ISOBMFF segments and MP4Box won't create segments slowly.

Because of limitations of Node.js's `fs.watch`, it's very important that the files be atomically moved into the live folder. A full inotify implementation wouldn't have this problem (it could watch for `IN_CLOSE_WRITE` before sending new files).

Currently it uses a static MPD because dynamic MPDs aren't working for me in DASH.js. If you have a player that supports dynamic MPD's, you can try running `generate_segments.py` with `--dynamic`.

This server currently adds a timeout to every request (60 seconds by default, configurable with `--timeout`) because it makes this easier to demonstrate with unmodified clients. If you want to require the "Timeout" header, add `--require-header`.
