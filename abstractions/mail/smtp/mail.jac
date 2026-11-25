import smtplib;
import from email.mime.text { MIMEText }
import from email.utils { formatdate, make_msgid, parseaddr }
import from common.contract { Host, Secret }
import from mail.contract { MailNotSent, Mailer }

glob WAIT_SECONDS: float = 20.0;

obj Smtp(Mailer) {
    has host: str = "",
        port: int = 587,
        sender: str = "",
        user: str = "",
        password: Secret = Secret(variable="SMTP_PASSWORD"),
        starttls: bool = True;

    has said_password: str postinit;

    def postinit;

    def open(host: dyn Host);

    def sends -> bool;

    def send(to: str, subject: str, text: str);
}
