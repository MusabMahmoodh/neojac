# mail

The standard mail: each letter handed to an SMTP server, which sends it
on. Every provider of mail takes it so, and so does a server of one's own.
A letter is one connection: none is kept between letters, and one the
server does not take is not tried again.

A letter is the standard library's MIMEText, which is written as the
program's other messages are (HTTP's headers); `EmailMessage` would bring the
newer header registry, five megabytes of every app that serves.

## WAIT_SECONDS

How long the server is waited for, in seconds.

## Smtp.host

The SMTP server: with none, the program sends no mail.

## Smtp.sender

Whom the mail is from, as its `From` says (`App
<no-reply@example.org>`): with no one, the program sends none.

## Smtp.user

Whom the server knows the program as, "" for a server that asks
no one, and their password, never written down.

## Smtp.starttls

Whether the connection is made private (STARTTLS) before anything
is said on it: false only where the mail crosses no network to
reach the server.

## Smtp.said_password

The password, as the program gives it.
