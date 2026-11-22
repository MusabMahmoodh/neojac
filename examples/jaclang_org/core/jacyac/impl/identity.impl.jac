impl name_of(display_name: str, username: str) -> str {
    return display_name or handle_of(username);
}

impl avatars_of(profiles: list[Profile]) -> dict[str, str] {
    shown: dict[str, str] = {};
    for p in profiles {
        picture = p.avatar;
        if picture is not None {
            shown[p.username] = picture.url();
        }
    }
    return shown;
}

impl avatar_of(avatars: dict[str, str], username: str) -> str {
    return avatars.get(username) or "";
}
