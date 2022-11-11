package tests

import "core:testing"
import la "core:math/linalg/glsl"
import "../events"

test_base_event :: proc(e: events.Event, category: bit_set[events.Event_Category], name: string) -> bool {
    be, ok := e.(events.Base_Event)
    return (be.handled == false) && (events.name(e) == name) 
}

@(test)
test_event_creation :: proc(t: ^testing.T) {
    event := events.app_update()
    testing.expect(t, test_base_event(event, {events.Event_Category.App}, "App Update"))
    event = events.app_render()
    testing.expect(t, test_base_event(event, {events.Event_Category.App}, "App Render"))

}