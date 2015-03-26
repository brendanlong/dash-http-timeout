# HTTP Timeout DASH Example

This example demonstrates a way to stream DASH segments with no HTTP-round-trip latency, using standard HTTP GET requests and HTTP/1.1.

## How it Works

The HTTP server (http-server.coffee) is a normal HTTP server, except that if a client requests a file that doesn't exist, instead of immediately returning a 404 response, it watches for the file to appear until its timeout expires. As soon as the file appears, it sends the response. If the file doesn't appear within the timeout, the server sends a 404 like usual.

## Setup

**Note: This relies on Node.js's `fs.watch` function, which only works properly on Linux. It could be adapted to other platforms, but it doesn't support them right now.**

Install Git, CoffeeScript, Node.js, NPM, Python 3, and [Google Chrome](https://www.google.com/chrome/browser/desktop/) (or some other browser that supports MSE, h.264 and AAC).

Fedora 21:

    sudo yum install coffee-script git nodejs npm python3

Ubuntu:

    sudo apt-get install coffeescript git nodejs npm python3

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

If you have the terminal and Chrome both on the screen the same time, you can see that playback starts the exact moment when the first segment appears on the filesystem (and because the Python script doesn't correct for clock delay, playback will pause slightly when the next segment should be available, and then immediately resumes when the segment becomes available).

**Sometimes this is a little buggy because DASH.js seems to give up if it gets a 404 for a segment. This would presumably not be a problem if we could use an MPD with type="dynamic". If playback stops early, close both programs with Ctrl+c and then start them up again and reload the page in Chrome.**

If you want to replay this example, just re-run the `generate_segments.py` command and refresh the page in Google Chrome. `generate_segments.py` will need confirmation before deleting the static/live directory, since deleting folders without asking tends to be a bad idea. See `./generate_segments.py --help` for more options (in case you want to delete that directory without asking, or if you want to use a different example stream).

If you want to play the MPD directly, it's at "/live/lifting-off.mpd".

## Caviats

`generate_segments.py` is a script which imitates a live DASH segmenter by copying files from one directory to another. When run, it immediately copies the MPD and initialization segments, optionally waits for a given delay, and then copies segment files in order, sleeping for their duration between copies. Ideally, this example would use a real segmenter, but FFMPEG can't create DASH ISOBMFF segments and MP4Box won't create segments slowly.

Currently it uses a static MPD because dynamic MPDs aren't working for me in DASH.js. If you have a player that supports dynamic MPD's, you can try running `generate_segments.py` with `--dynamic`.

This server currently adds a timeout to every request (60 seconds by default, configurable with `--timeout`) because it makes this easier to demonstrate with unmodified clients. If you want to require the "Timeout" header, add `--require-header`.
