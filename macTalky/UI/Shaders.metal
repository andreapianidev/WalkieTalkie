//creato da Andrea Piani - Immaginet Srl - 01/08/26 - https://www.andreapiani.com - Shaders.metal
//  macTalky
//
//  Suite Metal della console (SwiftUI colorEffect / layerEffect):
//  - talkyAurora  : campo fbm multi-ottava ambra/teal, reattivo a TX (verde)
//                   e RX (rosso), con ridges "onde radio", vignette e grain.
//  - talkyVU      : spettro a barre fosforo con peak-hold + onda composita.
//  - talkyCRT     : layerEffect stile tubo catodico — aberrazione cromatica,
//                   scanline, curvatura leggera, flicker.
//  - talkyPulse   : anelli radio concentrici in espansione attorno al PTT.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - Noise toolbox

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
    float2x2 rot = float2x2(0.8, 0.6, -0.6, 0.8);
    for (int i = 0; i < 6; i++) {
        v += amp * vnoise(p);
        p = rot * p * 2.03 + float2(17.1, 9.2);
        amp *= 0.55;
    }
    return v;
}

// MARK: - Tactical background

/// Sfondo console militare, parametrico e sobrio.
/// `base`/`tint`/`accent`: palette del tema selezionato.
/// `grid`: intensità griglia tattica; `sweep`: intensità radar sweep;
/// `motion`: quanta deriva ha la texture (0 = statica).
/// `tx`/`rx` (0...1): virata discreta verde/rossa dell'accento quando
/// si trasmette o si riceve — mai invadente.
[[ stitchable ]] half4 talkyTactical(float2 position, half4 color, float2 size,
                                     float time, float tx, float rx,
                                     half4 base, half4 tint, half4 accent,
                                     float grid, float sweep, float motion) {
    float2 uv = position / max(size.x, size.y);
    float t = time * 0.014 * motion;

    // Texture canvas: fbm a bassa energia, quasi impercettibile.
    float2 q = float2(fbm(uv * 3.0 + t), fbm(uv * 3.0 - t * 0.6));
    float cloth = fbm(uv * 5.5 + q * 0.8);

    float3 colBase = float3(base.rgb);
    float3 colTint = float3(tint.rgb);
    float3 colAcc  = float3(accent.rgb);

    float3 col = colBase;
    col = mix(col, colTint, cloth * 0.35);

    // Trama tessuto: micro-righe incrociate stile cordura.
    float weave = (sin(position.x * 1.9) * sin(position.y * 1.9)) * 0.5 + 0.5;
    col *= 0.97 + weave * 0.03;

    // Griglia tattica: linee sottili ogni ~64px con crocini ogni 4 celle.
    if (grid > 0.001) {
        float2 g64 = fract(position / 64.0);
        float lineX = smoothstep(0.028, 0.0, min(g64.x, 1.0 - g64.x));
        float lineY = smoothstep(0.028, 0.0, min(g64.y, 1.0 - g64.y));
        float gridLine = max(lineX, lineY) * 0.5;

        float2 g256 = fract(position / 256.0);
        float2 dc = abs(g256 - 0.5);
        float cross = (step(dc.x, 0.015) * step(dc.y, 0.05)
                     + step(dc.y, 0.015) * step(dc.x, 0.05));

        col = mix(col, colAcc, clamp(gridLine + cross * 0.9, 0.0, 1.0) * grid * 0.10);
    }

    // Radar sweep: settore rotante debolissimo dal centro.
    if (sweep > 0.001) {
        float2 c = uv - float2(size.x / max(size.x, size.y) * 0.5,
                               size.y / max(size.x, size.y) * 0.5);
        float ang = atan2(c.y, c.x);
        float sw = fract((ang / 6.28318) - time * 0.05);
        float beam = pow(1.0 - sw, 14.0);
        float falloff = exp(-length(c) * 2.2);
        col += colAcc * beam * falloff * sweep * 0.18;
    }

    // Stato TX/RX: alza appena l'accento, virato.
    float3 sig   = float3(0.30, 0.75, 0.42);
    float3 alarm = float3(0.85, 0.32, 0.24);
    float pulse = 0.85 + 0.15 * sin(time * 5.0);
    col = mix(col, col * 0.6 + sig * 0.25 * pulse, tx * 0.35);
    col = mix(col, col * 0.6 + alarm * 0.25 * pulse, rx * 0.35);

    // Vignette
    float2 vc = position / size - 0.5;
    float vig = 1.0 - dot(vc, vc) * 1.05;
    col *= clamp(vig, 0.3, 1.0);

    // Grain fine
    float g = hash21(position + fract(time) * 137.0);
    col += (g - 0.5) * 0.022;

    return half4(half3(col), color.a);
}

// MARK: - VU spectrum

/// Visualizer: 48 barre pseudo-spettro con peak-hold luminoso + onda
/// composita sovrapposta. `level` scala l'energia, `playing` accende tutto.
[[ stitchable ]] half4 talkyVU(float2 position, half4 color, float2 size,
                               float time, float level, float playing) {
    float2 uv = position / size;
    float energy = clamp(level, 0.0, 1.0) * playing;

    const float BARS = 48.0;
    float slot = floor(uv.x * BARS);
    float fx = fract(uv.x * BARS);

    // Altezza pseudo-spettro: somma di sinusoidi per banda + jitter noise.
    float f = slot / BARS;
    float h = 0.0;
    h += (0.55 + 0.45 * sin(f * 9.0 - time * 2.6)) * 0.45;
    h += (0.5 + 0.5 * sin(f * 23.0 + time * 4.2 + sin(time * 0.7) * 3.0)) * 0.30;
    h += vnoise(float2(slot * 0.7, time * 2.2)) * 0.45;
    // Roll-off sulle alte frequenze, punch sulle basse.
    h *= mix(1.25, 0.45, f);
    h = clamp(h * energy, 0.015, 0.95);

    float y = 1.0 - uv.y;             // 0 in basso
    float3 phosphor = float3(1.0, 0.68, 0.25);
    float3 hot = float3(0.24, 0.85, 0.45);

    float3 col = float3(0.0);
    float alpha = 0.0;

    // Corpo barra: acceso sotto h, con gradiente verso hot in alto.
    float inBar = step(y, h) * step(0.12, fx) * step(fx, 0.88);
    // Segmenti orizzontali stile VFD.
    float seg = step(0.25, fract(y * 28.0));
    float body = inBar * seg;
    float3 barCol = mix(phosphor * 0.85, hot, smoothstep(0.45, 0.9, y / max(h, 0.001)));
    col += barCol * body;
    alpha = max(alpha, body * 0.9);

    // Peak-hold: tacca luminosa che galleggia sopra la barra.
    float peak = h + 0.05 + 0.04 * sin(time * 3.0 + slot);
    float peakBand = smoothstep(0.012, 0.0, abs(y - peak)) * step(0.1, fx) * step(fx, 0.9) * playing;
    col += float3(1.0, 0.85, 0.5) * peakBand;
    alpha = max(alpha, peakBand);

    // Onda composita sovrapposta (fantasma dell'oscilloscopio).
    float wy = uv.y - 0.5;
    float w = sin(uv.x * 14.0 + time * 3.1) * 0.5
            + sin(uv.x * 27.0 - time * 4.7) * 0.28
            + sin(uv.x * 43.0 + time * 7.3) * 0.18;
    w *= 0.28 * energy * (0.55 + 0.45 * sin(uv.x * 3.14159));
    float d = abs(wy + w * 0.5);
    float wave = exp(-d * 60.0) * 0.6 * playing;
    col += phosphor * wave;
    alpha = max(alpha, wave);

    // Baseline da spento.
    float base = exp(-abs(wy) * 120.0) * 0.25 * (1.0 - playing);
    col += phosphor * base;
    alpha = max(alpha, base);

    return half4(half3(col), alpha * color.a);
}

// MARK: - CRT layer

/// Effetto tubo catodico per i display VFD: aberrazione cromatica ai bordi,
/// scanline, leggero bloom orizzontale e flicker di fosforo.
[[ stitchable ]] half4 talkyCRT(float2 position, SwiftUI::Layer layer,
                                float2 size, float time, float strength) {
    float2 uv = position / size;
    float2 centered = uv - 0.5;

    // Aberrazione cromatica proporzionale alla distanza dal centro.
    float ab = strength * 2.2 * dot(centered, centered);
    float2 dir = normalize(centered + 1e-5);
    half4 cr = layer.sample(position + dir * ab * 3.0);
    half4 cg = layer.sample(position);
    half4 cb = layer.sample(position - dir * ab * 3.0);
    half3 col = half3(cr.r, cg.g, cb.b);
    half a = cg.a;

    // Bloom orizzontale povero (3 tap): i fosfori sbavano di lato.
    half3 blur = (layer.sample(position + float2(2.0, 0)).rgb
                + layer.sample(position - float2(2.0, 0)).rgb) * 0.5h;
    col += blur * 0.18h;

    // Scanline
    float scan = 0.88 + 0.12 * sin(position.y * 2.4 + time * 1.5);
    // Flicker di rete elettrica
    float flick = 0.97 + 0.03 * sin(time * 47.0 + uv.y * 3.0);
    col *= half(scan * flick);

    return half4(col, a);
}

// MARK: - PTT pulse

/// Anelli concentrici in espansione dietro il tasto PTT.
/// `mode`: 0 = spento, 1 = TX (verde), 2 = RX (rosso).
[[ stitchable ]] half4 talkyPulse(float2 position, half4 color, float2 size,
                                  float time, float mode) {
    float2 c = position / size - 0.5;
    float rdist = length(c) * 2.0;             // 0 centro, 1 bordo
    float active = clamp(mode, 0.0, 2.0) > 0.5 ? 1.0 : 0.0;

    float3 tint = mode > 1.5 ? float3(0.95, 0.30, 0.22)   // RX
                             : float3(0.24, 0.85, 0.45);  // TX

    float glow = 0.0;
    // Tre anelli sfalsati che partono dal tasto (r≈0.55) e svaniscono al bordo.
    for (int i = 0; i < 3; i++) {
        float phase = fract(time * 0.55 + float(i) / 3.0);
        float rr = 0.55 + phase * 0.5;
        float band = exp(-pow((rdist - rr) * 26.0, 2.0));
        glow += band * (1.0 - phase);
    }
    // Alone statico attorno al tasto.
    glow += exp(-pow((rdist - 0.55) * 10.0, 2.0)) * 0.5;

    float alpha = clamp(glow, 0.0, 1.0) * 0.4 * active;
    return half4(half3(tint * glow), alpha * color.a);
}
