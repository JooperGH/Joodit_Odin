package tests

import "core:fmt"
import "core:testing"
import la "core:math/linalg/glsl"
import "../events"

test_base_event :: proc(e: events.Event, category: bit_set[events.Event_Category]) -> bool {
    return e.handled == false && e.category == category
}

@(test)
test_event_creation :: proc(t: ^testing.T) {
    event := events.app_update_start(0)
    testing.expect(t, test_base_event(event, {events.Event_Category.App}))
    event = events.app_render_start(0)
    testing.expect(t, test_base_event(event, {events.Event_Category.App}))
}