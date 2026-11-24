# FloatingSource

## FloatingSource

jac:ignore[E1053]

jac:ignore[E1053]

docked: dragging the titlebar past a small threshold pulls the
browser out of the hero into its floating window, which then
follows the cursor for the rest of the gesture

the width/height transition runs 300ms; clamp once it settles so an
expand near a viewport edge cannot push the titlebar off-screen

closing dismisses the float in place; the panel stays docked in the
hero for the main site, while the always-floating docs browser has
no dock and simply hides
