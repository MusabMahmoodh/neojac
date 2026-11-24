# contract

The contract of the `mail` abstraction: `Mailer`, the interface of the
plugin that sends a program's mail, and `MailNotSent`, what it raises for a
letter it could not send. No source names it: an `auth` plugin mails links
to its accounts' addresses through its host (`auth.contract`'s AuthHost).

## MailNotSent

A letter that was not sent, and why, as whoever runs the program reads
it: what the place that should have taken it said.

## Mailer

What sends a program's mail: the interface of the `mail` abstraction's
plugins.

- `open` is the first thing asked of it, given the program it runs in.
- `sends` is whether it sends mail at all: False for one given nowhere to
  send it, where a program offers nothing that needs mail.
- `send` sends a letter of plain `text` to the address `to`, with
  `subject`, from the address the plugin sends from: once, and MailNotSent
  where it was not taken.
