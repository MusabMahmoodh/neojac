"""The standard mail: each letter handed to an SMTP server, which sends it
on. Every provider of mail takes it so, and so does a server of one's own.
A letter is one connection: none is kept between letters, and one the
server does not take is not tried again.

A letter is the standard library's MIMEText, which is written as the
program's other messages are (HTTP's headers); `EmailMessage` would bring the
newer header registry, five megabytes of every app that serves."""

import smtplib;
import from email.mime.text { MIMEText }
import from email.utils { formatdate, make_msgid, parseaddr }
import from common.contract { Host, Secret }
import from mail.contract { MailNotSent, Mailer }

"""How long the server is waited for, in seconds."""
glob WAIT_SECONDS: float = 20.0;

obj Smtp(Mailer) {
    """The SMTP server: with none, the program sends no mail."""
    has host: str = "",
        port: int = 587,
        # Whom the mail is from, as its `From` says (`App
        # <no-reply@example.org>`): with no one, the program sends none.
        sender: str = "",
        # Whom the server knows the program as, "" for a server that asks
        # no one, and their password, never written down.
        user: str = "",
        password: Secret = Secret(variable="SMTP_PASSWORD"),
        # Whether the connection is made private (STARTTLS) before anything
        # is said on it: false only where the mail crosses no network to
        # reach the server.
        starttls: bool = True;

    # The password, as the program gives it.
    has said_password: str postinit;

    def postinit {
        self.said_password = "";
    }

    def open(host: dyn Host) {
        self.said_password = host.secret(self.password);
    }

    def sends -> bool {
        return self.host != "" and self.sender != "";
    }

    def send(to: str, subject: str, text: str) {
        try {
            letter = MIMEText(text);
            letter["From"] = self.sender;
            letter["To"] = to;
            letter["Subject"] = subject;
            letter["Date"] = formatdate();
            letter["Message-ID"] = make_msgid(domain=parseaddr(self.sender)[1].partition("@")[2]);
            with smtplib.SMTP(self.host, self.port, timeout=WAIT_SECONDS) as server {
                if self.starttls {
                    server.starttls();
                }
                if self.user != "" {
                    server.login(self.user, self.said_password);
                }
                server.sendmail(self.sender, [to], letter.as_string());
            }
        } except (OSError, ValueError) as e {
            raise MailNotSent(detail=f"{self.host}:{self.port} did not take a letter: {e}");
        }
    }
}
