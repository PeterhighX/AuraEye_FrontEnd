#include <metal_stdlib>
using namespace metal;

constant float tau = 6.28318530718;

static float hash21(float2 value) {
    value = fract(value * float2(123.34, 456.21));
    value += dot(value, value + 45.32);
    return fract(value.x * value.y);
}

static float2 organicOffset(float time, float phase) {
    float2 primary = float2(
        sin(time * 0.31 + phase) + 0.46 * sin(time * 0.17 + phase * 1.71),
        cos(time * 0.27 + phase * 0.83) + 0.42 * sin(time * 0.13 + phase * 2.17)
    );
    return primary / 1.46;
}

static float blobInfluence(float2 uv, float2 center, float2 radius) {
    float2 delta = (uv - center) / radius;
    return exp(-2.15 * dot(delta, delta));
}

[[ stitchable ]] half4 sharedFluidBackground(
    float2 position,
    half4 sourceColor,
    float2 size,
    float time,
    float motionAmount
) {
    float2 safeSize = max(size, float2(1.0));
    float2 uv = position / safeSize;
    float slowTime = time * 0.22;

    float2 orangeMotion = organicOffset(slowTime, 0.35) * float2(0.13, 0.065) * motionAmount;
    float2 purpleMotion = organicOffset(slowTime * 0.82, 2.47) * float2(0.15, 0.085) * motionAmount;
    float2 pinkMotion = organicOffset(slowTime * 1.08, 4.91) * float2(0.14, 0.095) * motionAmount;

    float orangeRadiusPulse = 1.0 + 0.055 * sin(slowTime * 0.41 + 0.8) * motionAmount;
    float purpleRadiusPulse = 1.0 + 0.065 * sin(slowTime * 0.33 + 2.4) * motionAmount;
    float pinkRadiusPulse = 1.0 + 0.060 * cos(slowTime * 0.37 + 4.2) * motionAmount;

    float orange = blobInfluence(
        uv,
        float2(0.73, 0.055) + orangeMotion,
        float2(0.70, 0.285) * orangeRadiusPulse
    );
    float purple = blobInfluence(
        uv,
        float2(0.22, 0.305) + purpleMotion,
        float2(0.76, 0.345) * purpleRadiusPulse
    );
    float pink = blobInfluence(
        uv,
        float2(0.78, 0.415) + pinkMotion,
        float2(0.74, 0.385) * pinkRadiusPulse
    );

    half3 orangeColor = half3(1.000h, 0.392h, 0.204h);
    half3 purpleColor = half3(0.506h, 0.525h, 1.000h);
    half3 pinkColor = half3(0.961h, 0.616h, 0.827h);

    // Preserve the original white lower page while keeping a warm, softly tinted top field.
    float verticalTint = 1.0 - smoothstep(0.46, 0.88, uv.y);
    half3 result = mix(half3(1.0h), half3(1.0h, 0.965h, 0.975h), half(0.32 * verticalTint));
    result = mix(result, orangeColor, half(orange * 0.53 * verticalTint));
    result = mix(result, purpleColor, half(purple * 0.39 * verticalTint));
    result = mix(result, pinkColor, half(pink * 0.34 * verticalTint));

    // A stable hash gives each dot its own speed and phase; the pairwise blob overlap
    // makes dots emerge where two or more colors are actually mixing.
    float dotSpacing = 12.0;
    float2 cell = floor(position / dotSpacing);
    float2 local = fract(position / dotSpacing) - 0.5;
    float seed = hash21(cell);
    float secondarySeed = hash21(cell + float2(17.0, 43.0));
    float dotRadius = mix(0.245, 0.315, secondarySeed);
    float dotShape = 1.0 - smoothstep(dotRadius - 0.035, dotRadius + 0.035, length(local));

    float pulseSpeed = mix(0.24, 0.47, seed);
    float rawPulse = 0.5 + 0.5 * sin(time * pulseSpeed + seed * tau);
    float randomFade = smoothstep(0.16, 0.88, rawPulse);
    float mixedField = saturate((orange * purple + orange * pink + purple * pink) * 2.75);
    float colorPresence = saturate(max(orange, max(purple, pink)) * 1.35);
    float dotRegion = (1.0 - smoothstep(0.42, 0.72, uv.y)) * verticalTint;
    float edgeFade = smoothstep(0.0, 0.035, uv.x)
        * smoothstep(0.0, 0.035, 1.0 - uv.x)
        * smoothstep(0.0, 0.025, uv.y);
    float dotAlpha = dotShape
        * dotRegion
        * edgeFade
        * colorPresence
        * mix(0.035, 0.30, mixedField)
        * mix(0.30, 1.0, randomFade);

    result = mix(result, half3(1.0h), half(saturate(dotAlpha)));
    return half4(result, sourceColor.a);
}
