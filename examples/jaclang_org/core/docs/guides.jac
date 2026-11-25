import json;
import os;
import tomllib;
import from pathlib { Path }

glob DOCS_ENV: str = "JAC_WEB_DOCS";

obj Guide {
    has name: str,
        description: str,
        body: str,
        path: str;
}

obj NavPage {
    has page: str,
        title: str,
        order: int,
        section: list[str];
}

def docs_dir -> Path;
def docs_version(docs_root: Path | None = None) -> str;

def parse_guide(path: Path) -> Guide | None;

def nav_manifest(docs_root: Path | None = None) -> dict[str, any];

def nav_pages(docs_root: Path | None = None) -> list[NavPage];

def _nav_walk(items: list[any], trail: list[str], pages: list[NavPage]);
