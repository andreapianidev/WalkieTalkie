//creato da Andrea Piani - Immaginet Srl - 01/08/26 - https://www.andreapiani.com - Shaders.metal
//  macTalky
//
//  Shader SwiftUI (colorEffect) per l'atmosfera "field radio console":
//  - talkyAurora: campo fbm lento ambra/teal su nero, con grana e vignette.
//  - talkyVU:     visualizer a onda fosforescente guidato da tempo + livello.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float hash21(float2 p) {
    p = fract(p * float2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

static float vnoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + float2(1, 0));
    float c = hash21(i + float2(0, 1));
    float d = hash21(i + float2(1, 1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float fbm(float2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 5; i++) {
        v += amp * vnoise(p);
        p = p * 2.03 + float2(17.1, 9.2);
        amp *= 0.55;
    }
    return v;
}

/// Sfondo aurora: nebbia lenta ambra + teal su carbone, vignette e grain.
[[ stitchable ]] half4 talkyAurora(float2 position, half4 color, float2 size, float time) {
    float2 uv = position / max(size.x, size.y);
    float t = time * 0.03;

    float2 q = float2(fbm(uv * 2.2 + t), fbm(uv * 2.2 - t * 0.7));
    float2 r = float2(fbm(uv * 3.1 + q * 1.4 + t * 0.5),
                      fbm(uv * 3.1 - q * 1.1 - t * 0.3));
    float field = fbm(uv * 2.4 + r * 1.6);

    // Palette: carbone → ambra bruciata → teal fantasma
    float3 coal  = float3(0.030, 0.034, 0.040);
    float3 amber = float3(0.85, 0.55, 0.16);
    float3 teal  = float3(0.10, 0.42, 0.40);

    float3 col = coal;
    col = mix(col, amber * 0.32, smoothstep(0.35, 0.85, field) * 0.65);
    col = mix(col, teal * 0.30, smoothstep(0.55, 0.95, q.y) * 0.45);

    // Vignette dolce
    float2 c = position / size - 0.5;
    float vig = 1.0 - dot(c, c) * 1.15;
    col *= clamp(vig, 0.25, 1.0);

    // Grain animato
    float g = hash21(position + fract(time) * 137.0);
    col += (g - 0.5) * 0.035;

    return half4(half3(col), color.a);
}

/// Visualizer VU: onde fosforo-ambra sommate, ampiezza pilotata da `level`.
[[ stitchable ]] half4 talkyVU(float2 position, half4 color, float2 size, float time, float level, float playing) {
    float2 uv = position / size;
    float x = uv.x;
    float y = uv.y - 0.5;

    float amp = mix(0.02, 0.42, clamp(level, 0.0, 1.0)) * playing;
    float w = 0.0;
    w += sin(x * 12.0 + time * 3.1) * 0.55;
    w += sin(x * 23.0 - time * 4.7) * 0.28;
    w += sin(x * 41.0 + time * 7.3) * 0.17;
    w *= amp * (0.55 + 0.45 * sin(x * 3.14159));

    float d = abs(y - w);
    float core = exp(-d * 90.0);
    float glow = exp(-d * 18.0) * 0.5;

    float3 phosphor = float3(1.0, 0.68, 0.25);
    float3 col = phosphor * (core + glow);

    // Linea di base sempre visibile (stile oscilloscopio spento)
    float base = exp(-abs(y) * 120.0) * 0.25 * (1.0 - playing);
    col += phosphor * base;

    float alpha = clamp(core + glow + base, 0.0, 1.0);
    return half4(half3(col), alpha * color.a);
}
