package tests

import "core:testing"
import la "core:math/linalg/glsl"
import "core:fmt"

@(test)
test_vec2_addition :: proc(t: ^testing.T) {
    v1 := la.vec2{5.0, 3.0}
    v2 := la.vec2{1.0, -1.0}
    vresult := v1 + v2
    testing.expect_value(t, vresult.x, 6.0)
    testing.expect_value(t, vresult.y, 2.0)
}