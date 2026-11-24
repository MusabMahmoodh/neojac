graph layers {
    """What Expo is run with, and the project it is given."""
    layer bundler { *; }
}

graph import {
    "expo-project" --> expo { prepare }
    "expo-project" --> "expo.serve" { prepare }
}
