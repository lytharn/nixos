// Cursor trail effect for Ghostty.
// Runs as a post-process shader; see custom-shader in the Ghostty docs:
//   https://ghostty.org/docs/config/reference#custom-shader
//
// Ghostty provides these Shadertoy-compatible uniforms:
//   iResolution        viewport resolution in pixels
//   iTime              shader playback time in seconds
//   iChannel0          the rendered terminal (already includes the cursor)
//   iCurrentCursor     vec4(x, y, w, h) of the cursor, top-left origin (y down)
//   iPreviousCursor    vec4 cursor rect before the last move
//   iTimeCursorChange  iTime value when the cursor last moved

const vec3  TRAIL_COLOR = vec3(0.13, 0.42, 1.0); // smear tint (saturated azure blue)
const float DURATION    = 0.25;                  // seconds for the tail to catch up
const float THICKNESS   = 1.0;                   // smear width, relative to cursor height
const float MIN_CELLS   = 3.0;                   // ignore moves shorter than this (typing)

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Cursor rect to its center. Ghostty uses the same bottom-left origin as
// fragCoord, with c.y being the cursor's top edge, so drop down half a height.
vec2 cursorCenter(vec4 c) {
    return vec2(c.x + c.z * 0.5, c.y - c.w * 0.5);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);

    vec2 cur  = cursorCenter(iCurrentCursor);
    vec2 prev = cursorCenter(iPreviousCursor);
    vec2 size = iCurrentCursor.zw;

    float t = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);
    float ease = 1.0 - pow(1.0 - t, 3.0); // ease-out cubic

    // Tail lags behind, interpolating from the old position to the new one.
    vec2 tail = mix(prev, cur, ease);

    // Capsule connecting the lagging tail to the current cursor.
    float d = sdSegment(fragCoord, tail, cur) - size.y * 0.5 * THICKNESS;

    // Suppress short hops (e.g. typing, which advances one cell at a time);
    // only larger jumps smear. Soft ramp so it isn't an abrupt cutoff.
    // Use the line height (size.y) as the unit since the cursor width (size.x)
    // is unreliable for thin beam/bar cursors; estimate cell width from it.
    float cellWidth = size.y * 0.5;
    float moved = length(cur - prev);
    float moveGate = smoothstep(MIN_CELLS * cellWidth, (MIN_CELLS + 1.0) * cellWidth, moved);

    // Soft edge, fading the whole smear out as the cursor settles.
    float alpha = smoothstep(2.0, -2.0, d) * (1.0 - ease) * moveGate;

    fragColor.rgb = mix(fragColor.rgb, TRAIL_COLOR, alpha);
}
