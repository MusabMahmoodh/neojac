import logging;
import os;
import re;
import time;

comptime SYNC_TICK_S: float = 30.0;

glob RECHECK_S: float = 600.0,
     SYNC_STATE: dict[str, float] = {},
     UNNAMED_SECTION: str = "Other pages",
     log: logging.Logger = logging.getLogger("docs.sync");
def corpus_bundle -> DocBundle;

def first_h1(text: str) -> str;

def rewrite_links(text: str, version: str, rel: str) -> str;

def build_version(bundle: DocBundle) -> DocVersion;

def corpus_stale(bundle: DocBundle) -> bool;

def ingest(bundle: DocBundle);
def retire_versions(keep: list[str]);

@schedule(interval=SYNC_TICK_S)
def:protect docs_sync_tick;
