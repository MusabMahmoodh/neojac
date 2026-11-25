import hashlib;
import os;
import re;
import from pathlib { Path }

glob BUILD_FORMAT: str = "4";

obj NavEntry {
    has page: str = "",
        title: str = "",
        order: int = 0,
        section: list[str] = [];
}

obj DocBundle {
    has pages: dict[str, str] = {},
        descriptions: dict[str, str] = {},
        nav: dict[str, NavEntry] = {},
        version: str = "",
        fingerprint: str = "";
}

def label_of(version: str) -> str;
def reader_text(body: str) -> str;
def bundle_from(ddir: Path) -> DocBundle;
