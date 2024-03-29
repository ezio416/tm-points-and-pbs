// c 2024-03-29
// m 2024-03-29

// from https://github.com/XertroV/tm-cotd-hud/blob/422a1fc4be32b969de6a76355b3a2c03b5cc8034/src/Color.as

dictionary@ darkModeCache = dictionary();

enum ColorTy {
    HSL,
    RGB
}

float h2RGB(float p, float q, float t) {
    if (t < 0.0f)
        t += 1.0f;

    if (t > 1.0f)
        t -= 1.0f;

    if (t < 0.16667f)
        return p + (q - p) * 6.0f * t;

    if (t < 0.5f)
        return q;

    if (t < 0.66667f)
        return p + (q - p) * 6.0f * (2.0f / 3.0f - t);

    return p;
}

uint8 HexCharToInt(int char) {
    if (IsCharInt(char))
        return char - 48;

    if (IsCharInAToF(char)) {
        const int v = char - 65 + 10;  // A = 65 ascii

        if (v < 16)
            return v;

        return v - (97 - 65);  // a = 97 ascii
    }

    throw("HexCharToInt got char with code " + char + " but that isn't 0-9 or a-f or A-F in ascii.");

    return 0;
}

vec3 hslToRGB(vec3 hsl) {
    const float h = hsl.x / 360.0f;
    const float s = hsl.y / 100.0f;
    const float l = hsl.z / 100.0f;
    float       r, g, b, p, q;

    if (s == 0)
        r = g = b = l;
    else {
        q = l < 0.5f ? (l + l * s) : (l + s - l * s);
        p = 2.0f * l - q;
        r = h2RGB(p, q, h + 1.0f / 3.0f);
        g = h2RGB(p, q, h);
        b = h2RGB(p, q, h - 1.0f / 3.0f);
    }

    return vec3(r, g, b);
}

bool IsCharHex(int char) {
    return IsCharInt(char) || IsCharInAToF(char);
}

bool IsCharInAToF(int char) {
    return (97 <= char && char <= 102)  // lower case
        || (65 <= char && char <= 70);  // upper case
}

bool IsCharInt(int char) {
    return 48 <= char && char <= 57;
}

string MakeColorsOkayDarkMode(const string &in raw) {
    if (darkModeCache.Exists(raw))
        return string(darkModeCache[raw]);

    string ret = string(raw);
    string test;

    for (int i = 0; i < int(ret.Length) - 3; i++) {
        if (ret[i] == "$"[0]) {
            test = ret.SubStr(i, 4);

            if (IsCharHex(test[1]) && IsCharHex(test[2]) && IsCharHex(test[3])) {
                Color@ color = Color(vec3(
                    float(HexCharToInt(test[1])) / 15.0f,
                    float(HexCharToInt(test[2])) / 15.0f,
                    float(HexCharToInt(test[3])) / 15.0f
                ));

                color.AsHSL();

                const float lightness = color.vec.z;

                if (lightness < 60.0f) {
                    color.vec = vec3(color.vec.x, color.vec.y, Math::Max(100.0f - lightness, 60.0f));
                    ret = ret.Replace(test, color.ManiaColor);
                }
            }
        }
    }

    darkModeCache[raw] = ret;

    return ret;
}

vec3 rgbToHSL(vec3 rgb) {
    const float r   = rgb.x;
    const float g   = rgb.y;
    const float b   = rgb.z;
    const float max = Math::Max(r, Math::Max(g, b));
    const float min = Math::Min(r, Math::Min(g, b));
    float       h, s;
    const float l = (max + min) / 2.0f;

    if (max == min)
        h = s = 0.0f;
    else {
        const float d = max - min;
        s = l > 0.5f ? d / (2.0f - max - min) : d / (max + min);
        h = max == r
            ? (g-b) / d + (g < b ? 6.0f : 0.0f)
            : max == g
                ? (b - r) / d + 2.0f
                /* it must be that: max == b */
                : (r - g) / d + 4.0f;
        h /= 6.0f;
    }

    return vec3(
        Math::Clamp(h * 360.0f, 0.0f, 360.0f),
        Math::Clamp(s * 100.0f, 0.0f, 100.0f),
        Math::Clamp(l * 100.0f, 0.0f, 100.0f)
    );
}

uint8 ToSingleHexCol(float v) {
    if (v < 0.0f)
        v = 0.0f;

    if (v > 15.9999f)
        v = 15.9999f;

    const int u = uint8(Math::Round(v));

    if (u < 10)
        return 48 + u;  // 48 = '0'

    return 87 + u;  // u >= 10 and 97 = 'a'
}

class Color {
    ColorTy ty;
    vec3    vec;

    Color(vec3 vec, ColorTy ty = ColorTy::RGB) {
        this.ty  = ty;
        this.vec = vec;
    }

    string get_ManiaColor() {
        const vec3 v = rgb * 15.0f;
        string ret = "000";

        ret[0] = ToSingleHexCol(v.x);
        ret[1] = ToSingleHexCol(v.y);
        ret[2] = ToSingleHexCol(v.z);

        return "$" + ret;
    }

    vec3 get_rgb() {
        switch (ty) {
            case ColorTy::HSL: return hslToRGB(vec);
            case ColorTy::RGB: return vec;
            default: throw("Unknown color type: " + tostring(ty));
        }

        return vec3();
    }

    void AsHSL() {
        if (ty == ColorTy::RGB)
            vec = rgbToHSL(vec);

        ty = ColorTy::HSL;
    }
}
