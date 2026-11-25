obj ProfileBundle {
    has profile: Profile,
        followers: list[Profile],
        following: list[Profile],
        tweets: list[Tweet];
}

obj ChannelBundle {
    has channel: Channel,
        member_count: int,
        is_member: bool,
        posts: list[Tweet] = [];
}

obj TrendingTag {
    has tag: str,
        count: int;
}

obj FieldCheck {
    has ok: bool = True,
        error: str = "",
        value: str = "";
}

obj ProfileResult {
    has ok: bool = False,
        error: str = "",
        bundle: ProfileBundle | None = None;
}

node Profile {
    has username: str = "",
        display_name: str = "",
        bio: str = "",
        location: str = "",
        website: str = "",
        github: str = "",
        avatar: File | None = None,
        created_at: str = "";
}

node Tweet {
    has content: str = "",
        author_username: str = "",
        created_at: str = "",
        likes: list[str] = [],
        comments: list[dict[str, str]] = [];
}

node Channel {
    has name: str = "",
        description: str = "",
        creator_username: str = "",
        created_at: str = "";
}

obj PostingDenied {
    has message: str,
        retry_after_seconds: int;
}

obj Posted {
    has tweet: Tweet | None = None,
        denied: PostingDenied | None = None;
}

obj Liked {
    has liked: bool,
        likes: list[str];
}

obj Commented {
    has comment: dict[str, str] = {},
        denied: PostingDenied | None = None;
}
