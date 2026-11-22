def name_of(display_name: str, username: str) -> str;

"""Where each of `profiles` shows its picture from, by its user's name: the
address of the file its profile holds. One with no picture has none."""
def avatars_of(profiles: list[Profile]) -> dict[str, str];

def avatar_of(avatars: dict[str, str], username: str) -> str;
