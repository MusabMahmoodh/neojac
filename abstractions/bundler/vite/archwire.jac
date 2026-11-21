graph layers {
    """What Vite is run with, and what it loads of a Jac page."""
    layer bundler { *; }
}

graph import {
    "vite-plugin" --> vite { prepare }
    "vite-plugin" --> vite.serve { prepare }
}
