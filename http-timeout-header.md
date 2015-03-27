# HTTP Timeout Header

This defines a new HTTP header, "Timeout", which indicates to a server that if the requested resource does not exist, the server should watch for it until the timeout expires before sending a 404. The value is milliseconds as an integer.

If an "If-None-Match" header is also sent by a client, it indicates that the server should also wait until the etag changes before responding (how etags are generated is up to servers).

A server should have a maximum timeout, to prevent clients from wasting server resources with unreasonably long timeouts.

## Simple Example

    GET /dash/representation-1/segment-2.mp4
    Timeout: 5000

### Server Handling

 1. If the requested resource exists, the HTTP server will immediately send a 200 or 304 response with the content.

 2. If the resource does not exist, and the server doesn't understand this header, it will immediately send a 404 response as usual.

 3. If the requested resource becomes available before the timeout expires, the server will send a 200 response with the content.

 4. If the timeout expires and the requested resource is not available, the server will send a 404 response.

## ETag Example

    GET /dash/representation-1/segment2.mp4
    Timeout: 5000
    If-None-Match: W/"52d77-3355156460"

### Server Handling

 1. If the server does not understand these headers, it responds as usual (200, 304, or 404).

 2. When the file becomes available or updates:

     1. The server generates an etag.
     2. If the etag doesn't match the "If-None-Match" header, the server sends a 200 response.

 3. If the timeout expires, the server responds as usual (200, 304 or 404).

## Use Case: MPEG-DASH

In MPEG-DASH, a live streaming server could offer an MPD with a `<SegmentTemplate>` like:

    <SegmentTemplate media="segment-$Number$.mp4" duration="1"/>

This indicates that the segments will be named "segment-0.mp4", "segment-1.mp4", etc., and each segment is approximately one second long. Each segment will be available at time `MPD@availabilityStartTime + (SegmentTemplate@duration × $Number$)`. Using that information, a client which is currently playing segment 0 can request segment 1 with:

    GET /segment-1.mp4
    Timeout: 2000

Unless something is seriously wrong on the server side (which would cause the client to pause no matter what), this segment will be delivered by the client as soon as it is available. While segment 1 is being delivered, the client can request segment 2, and so on.

A client could also make multiple future segment requests in order:

    GET /segment-1.mp4
    Timeout: 2000

    GET /segment-2.mp4
    Timeout: 3000

    Get /segment-3.mp4
    Timeout: 4000

However, I don't think there's any advantage to doing this. I mention it as an example, because it came up in a previous conversation.

The If-None-Match / ETag version can be used to receive dynamic MPD updates immediately.

## Compared to K-Push

### Downsides

#### Predictable Segment URLs

The biggest downside to this compared to K-push is that the segment names need to be predictable so that the client can request them. In practice, this means that the MPD can't use `<SegmentTemplate>`'s `$Time$` identifier. Any other `<SegmentTemplate>` or `<SegmentList>` should work.

This seems like a very minor concession in order to have low-latency live streaming.

#### Tiny Bandwidth Savings

An HTTP request can be a few hundred bytes, so using K-push can reduce bandwidth by approximate (100 × K) bytes.

However, the purpose of this is live streaming, which involves several MB files. Presumably any network which can transfer several million byte video segments can handle the hundred bytes to request them. In my opinion, saving 0.01% of bandwidth should not be a consideration.

### Upsides

#### Works Now (HTTP/2 Not Required)

The Timeout header doesn't require HTTP/2 at all, although its improved pipelining features would be useful. In the DASH case, HTTP/1.1's head-of-line blocking wouldn't be an issue for this though, since we need the current segment to finish downloading before the next segment is playable.

See [https://github.com/brendanlong/dash-http-timeout] for an example server which works **right now** in Google Chrome.

#### Matches HTTP Better

Both K-push and this header solve the problem: The client wants to request a resource, but it doesn't exist yet. K-push solves this by embedding requests in headers and expecting servers to push them. This header solves the problem by explicitly supporting that use-case in GET requests.

In my opinion, if we want to request a resource, we should use an HTTP request, not headers and PUSH_PROMISE.

#### K-Push is Complicated When K < Number of Segments

In K-push, you make a request for a particular segment, and add a header indicating a request for K future segments:

    GET /segment-0.mp4
    K-Push: 5

The problem occurs once the server has pushed K segments. The client now needs to request a new segment, but it can't request segment K + 1, because that segment doesn't exist yet. It can't request segment K, because the server is already pushing that segment (and presumably we don't want to download it twice).

Similar problems occur when switching representations or when starting streams.

A solution to this is to send a HEAD request with the K-push header, but now we're embedding multiple GET requests in a HEAD request, rather than just adding a header to GET to indicate what we want. This also won't help if we want to request that segment 0 be pushed when it becomes available (if a client tunes into a stream before it starts).

This could also be solved by setting K to infinity, and ending pushing by fully closing the client request stream (since a PUSH_PROMISE has to be associated with a previous explicit client request). This introduces problems in JavaScript clients because they have no way to control whether or not an HTTP/2 stream if left "half-open" or not.

#### JavaScript Clients Can't Leave Streams "half-open"

Related to the previous problem, a JavaScript client can't ensure that a browser will leave a request "half-open". If a client sends a request with the K-push header, but the browser closes the request, the server won't be able to push responses.

This problem doesn't occur with the Timeout header, because each request is an explicit HTTP request, which the browser will leave open until its timeout is reached (and the timeout can be controlled using `XMLHTTPRequest.timeout`).

#### Reduced Server Complexity

In both cases, the server needs to watch the server for new files, but in the Timeout case, the client tells the server exactly which file to look for. In the K-push case, the server needs to know what the next K segments are (by parsing the MPD, or some other method like having a list of segments for each representation, and logic to parse those files and relate segments to each other in order).

Note that in [https://github.com/brendanlong/dash-http-timeout], the server has no idea what content it's server.
