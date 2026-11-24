# transport

The standard transport: requests carried over HTTP, a call's reply
as JSON and a stream's events as they are made (`text/event-stream`), and the
server that answers them.

The server answers each call on a thread of its own, so a call that waits (for
a model, for an event another call makes) holds no other up, and a stream
endpoint's events go out as it makes them. The threads take turns as a
program's own do (the runtime's Jac lock): one runs at a time, and gives way
where it waits. Its loop accepts and reads requests, and runs what the
program has for it between them.

## MAX_HEAD

The most a request's head and body may be.

The most connections open at once: past it, the one open longest is
let go for the next. (select() watches descriptors below 1024.)

How long a connection may take to send its request.

How long a refused request's client may go on sending after its answer.

The most calls answered at once: one past it waits for a thread.

How long a thread that answers calls waits for one before it ends.

How long a stream may say nothing before the server says it is still
there: a comment, which a reader passes over.

## Refused

A request the server won't read: answered with `status`, saying `detail`,
and its connection closed.

## parse_request

The request `buf` holds, once all of it has come; None until then. Raises
Refused for one the server won't read, with the status that says why.

Only a body whose length its head gives is read.

## reads_interim

Whether the client of the request `buf` holds, whole, reads interim
replies, which one waiting for a call that takes long is sent: HTTP/1.0's
does not.

## write_response

A socket is `any` here: on cpython it's CPython's, whose classes can't be
named as types yet.
A reply whose body is `pieces` is sent each as it is read, so a body is
never held whole; a reply to a HEAD sends its head, with the length its
body would have, and no body.

## respond

What `handle` answers `req`: a failure of its own is the server's (500),
and says nothing of what failed.

## client_of

Where a request with `headers` came from, when its connection came from
`peer`: the one address the header `named` holds, for a server a gateway
writes it for, and `peer` where no header is named, or the request carries
none, or what it carries is not one address. A request the gateway did not
carry (the probe of whatever runs the program) carries none, and is its
peer's.

## Sending

A connection a client is waiting on: a stream being sent, or a call
that has not been answered yet (`interim`). Its connection, what holds it
while something is written to it, and when something last was.

## Calls

The threads that answer calls: as many as there are calls being answered,
and no more. A call is handed to one that waits, and a thread is started only
when every one of them has a call (a thread costs a heap of its own), up to
MAX_CALLS; one that has waited IDLE_SECONDS for a call ends.

Nothing the loop's thread made is handed to a call's thread to drop. A block
one thread frees goes to that thread's heap and never back to the heap it
came from, so what the loop made for each request, dropped by the thread that
answered it, would be memory the loop never had again. A call is handed over
as numbers: its connection's descriptor, of which its thread makes a socket
of its own, and a ticket for its request's bytes, which stay the loop's: the
call's thread reads its own Request out of them, and the loop drops them.

## Calls.answer

(Given a call's connection, its request, and whether its client reads
interim replies.)

## Calls.client_header

The header a gateway writes each request's client into
(HttpTransport's setting), its name lowercased.

## Calls.queued

Each call waiting for a thread: its descriptor, then its ticket.

## Calls.held

Each request's bytes by its ticket, and the tickets whose bytes
their calls' threads have read.

## Calls.open

The calls taken that are not yet answered.

## Calls.take

Have a thread answer the request `request` holds, whole, on the
connection whose descriptor is `descriptor`: the loop's to ask.

## Calls.settle

Drop the bytes of the requests their calls' threads have read: the
loop's to do, as it turns.

## Calls.answered

A call was answered: its thread is as good as free.

## Calls.work

A thread's life: the calls it is handed, one after another.

(Woken for a call another thread took first, it waits
on: only one that waited the whole time ends.)

(The loop read it as a whole request: this is not reached.)

## answer_on

Answer `req` on `conn` and close it: a call's whole life, on a thread of
its own. A stream's events are sent each as it is made, to a client that is
told nothing of their length and reads until the connection closes; one whose
client has gone is closed where it paused.

While its endpoint runs, its client is told every KEEPALIVE_SECONDS
that the call is still being answered (keep_alive), so a caller
gives up on a server that has gone silent, not on a call that takes
long. Nothing is told it once its reply is to be written.

(Said before its reply is written: the client's next request
may come before this thread runs again.)

Ended, or its client went: closed where it paused, so
what the endpoint owes there runs.

The client went or stalled: nothing more is owed it.

(Closed already.)

## keep_alive

Tell the reader of each stream that has said nothing for
KEEPALIVE_SECONDS that it is still there, and the caller of each call that
has not been answered for as long that it is being answered (an interim
reply, which a client passes over), where that takes no waiting.

(Its client has gone: the stream's own thread finds out.)

## events_of

Each event of the stream reply `r`, whole, as it comes: one cut short ends
as it was cut.

## Bound

An address this transport took for its program: the socket that listens
there, which the loop takes connections from.

## Bound.sock

(A socket is `any`: on cpython it is CPython's, whose classes can't be
named as types yet.)

## HttpTransport.client_header

The header a gateway in front of this server writes each request's
client address into, having taken out what any caller sent under that
name: an Envoy that takes a connection's own address for its client
writes `x-envoy-external-address`. A request's client is then what that
header holds, and limits count callers apart. It is named only where
nothing but such a gateway reaches the server: whoever else does says
what client they like. "", the default: a request's client is the
address its connection came from.

## HttpTransport.work

Work for the loop to do on its own thread, the one the program started
on, and the pair of sockets that wakes the loop for it, once it listens.

## HttpTransport.open

Nothing to open: it asks nothing of the program, and takes its address
when it is told to (`claim`).

## HttpTransport.send

`r`, sent to the app at `address` (`http://host:port`): its reply. A
status that says the request failed is still a reply.

## HttpTransport.serves_paths

A request over HTTP names any path.

## HttpTransport.claim

A socket listening at `address` (`host:port`; port 0, one the system
picks). CannotListen where it can't: an address that is not a host and a
port, with the system's reason where the system refused it.

## HttpTransport.listen

Serves `handle` at the address `claim` took. The loop takes
connections and reads requests; each whole request is answered on a
thread of its own (`answer_on`), at most MAX_CALLS at once. Nothing a
client sends or does ends it: a request it won't read is refused with the
status that says why, a connection that can't be taken is let be, at
most MAX_CONNECTIONS are open with a request still to come, and each has
REQUEST_SECONDS to send its request.

Flushed: what starts the server reads it to learn the port (one the
system chose, for port 0). The address is the one the socket is
bound to: a host name's, as it resolved.

(A pair of sockets, not a pipe: select watches only sockets on Windows.)

A refused request's connection, answered before all of it was read:
until when what more its client sends is read and let go, so the
client reads the answer rather than a reset (RFC 9112's closing).

Forget connection `fd`, closing it unless a call has taken it.

A connection that says nothing costs nothing: only one with data is read.

(Work was asked for: done at the top of the next turn.)

The one open longest makes way.

Gone before it was taken, or no descriptor for it: one
open longest makes way, and the loop goes on.

(Made way for another this turn.)

The call's from here: its thread makes its own
socket of the descriptor, and its own Request.

The client went or stalled (an OSError): its connection goes.
