# model

The standard model: a model behind Anthropic's Messages API, over
HTTP. A request the model's safety classifiers decline re-runs on the API's
default fallback model. The instructions are sent marked for the API's prompt
cache, so the requests of one call, and calls with the same instructions,
read them from it.

## api_message

`m` as the API takes a message.

## reply_message

The Message the API's message `m` is: its text and its tool calls, and
what else it holds (its thinking, with its signature) kept as it came.

## strict_schema

A schema as structured outputs takes it, or None when it leaves something open
(`any`, or a dict), which that can't express.

## strict_result

The object a result travels in: structured outputs' top level is an object.

## usage_of

What a reply says its request used.

## Anthropic.key

The API's key, which is never written down: `ANTHROPIC_API_KEY`
where the program runs.

## Anthropic.model

The model that answers.

## Anthropic.address

Where the API is: a gateway to it, in its place.

## Anthropic.timeout

Seconds one request may take.

## Anthropic.retries

How many times a request the API refuses for load (408, 409, 429,
5xx) or cannot be reached with is made again, after 2, 4, 8 ...
seconds.

## Anthropic.given_key

The API's key, as the program it was opened in gives it: "" where it
gives none.

## Anthropic.open

It takes its key from the program, and reaches the API when it is
asked (`ask`).

## Anthropic.post

One request, made: the API's response to read.

## Anthropic.read_events

The reply the API streams on `r`: each piece of its text as a TEXT
event, then a DONE whose `value` is the whole reply, as the API's
message.

(A tool call's input comes as pieces of its JSON, by its block.)

(Sent back as it came, with its signature: the model's own
thinking, which may come with no text.)

## Anthropic.ask

(Said again with every request of the call: kept by the API
between them.)

The answer travels in an object, the API's own form for one:
the value in it is what was asked for.

(Not JSON: said as it came, for what asked to refuse.)
