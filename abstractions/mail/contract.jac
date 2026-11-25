import from common.contract { Host }

obj MailNotSent(Exception) {
    has detail: str;

    def __str__ -> str;
}

obj Mailer {
    def open(host: dyn Host) abst;
    def sends -> bool abst;
    def send(to: str, subject: str, text: str) abst;
}
