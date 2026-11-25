impl Smtp.postinit {
    self.said_password = "";
}

impl Smtp.open(host: dyn Host) {
    self.said_password = host.secret(self.password);
}

impl Smtp.sends -> bool {
    return self.host != "" and self.sender != "";
}

impl Smtp.send(to: str, subject: str, text: str) {
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
