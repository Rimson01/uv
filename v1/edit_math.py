"""Shared arithmetic definitions for CPU tests and generated MAXScript.

The export embeds the emitted MAXScript; users do not need Python files.
"""
import ast
import math


OPERATIONS = {
    "align_u_min": ("U 최소 정렬", ("min_u", "v", "w")),
    "align_u_center": ("U 중심 정렬", ("center_u", "v", "w")),
    "align_u_max": ("U 최대 정렬", ("max_u", "v", "w")),
    "align_v_min": ("V 최소 정렬", ("u", "min_v", "w")),
    "align_v_center": ("V 중심 정렬", ("u", "center_v", "w")),
    "align_v_max": ("V 최대 정렬", ("u", "max_v", "w")),
    "nudge_u_plus": ("U 미세 이동 +", ("u + amount", "v", "w")),
    "nudge_u_minus": ("U 미세 이동 -", ("u - amount", "v", "w")),
    "nudge_v_plus": ("V 미세 이동 +", ("u", "v + amount", "w")),
    "nudge_v_minus": ("V 미세 이동 -", ("u", "v - amount", "w")),
    "rotate": ("선택 UV 회전", (
        "center_u + cosine * (u - center_u) - sine * (v - center_v)",
        "center_v + sine * (u - center_u) + cosine * (v - center_v)", "w")),
    "scale": ("선택 UV 크기", (
        "center_u + (u - center_u) * amount", "center_v + (v - center_v) * amount", "w")),
    "scale_u": ("U 크기", ("center_u + (u - center_u) * amount", "v", "w")),
    "scale_v": ("V 크기", ("u", "center_v + (v - center_v) * amount", "w")),
    "snap_u": ("U 픽셀 격자", ("snap_u", "v", "w")),
    "snap_v": ("V 픽셀 격자", ("u", "snap_v", "w")),
    "distribute_u": ("U 간격 균등", ("distributed_u", "v", "w")),
    "distribute_v": ("V 간격 균등", ("u", "distributed_v", "w")),
    "mirror_u": ("U 반전", ("2 * center_u - u", "v", "w")),
    "mirror_v": ("V 반전", ("u", "2 * center_v - v", "w")),
    "center_tile": ("선택 중심을 0.5, 0.5로 이동", (
        "u + 0.5 - center_u", "v + 0.5 - center_v", "w")),
}
COLOR_EXPRESSIONS = ("red / 255.0", "green / 255.0", "blue / 255.0")
SLOT_STRIP = ("_", " ", "/", "-", "(", ")", ":")
BASE_SLOT_NAMES = ("base", "basecolor", "basealbedo", "basecoloralbedo", "albedo",
                   "diffuse", "diffusecolor", "basecolordiffuse", "basemap", "basecolormap",
                   "basealbedomap", "albedomap", "diffusemap", "diffusecolormap")


def is_base_slot(name):
    normalized = name.lower()
    for character in SLOT_STRIP:
        normalized = normalized.replace(character, "")
    return normalized in BASE_SLOT_NAMES


def _evaluate(expression, values):
    tree = ast.parse(expression, mode="eval")
    allowed = (ast.Expression, ast.BinOp, ast.Name, ast.Load, ast.Constant,
               ast.Add, ast.Sub, ast.Mult, ast.Div)
    if any(not isinstance(node, allowed) for node in ast.walk(tree)):
        raise ValueError("Unsupported shared arithmetic")
    return eval(compile(tree, "<workbench arithmetic>", "eval"), {"__builtins__": {}}, values)


def normalize_color(red, green, blue):
    components = (red, green, blue)
    if any(not math.isfinite(c) or c < 0 or c > 255 for c in components):
        raise ValueError("Expected RGB components in 0..255")
    context = dict(zip(("red", "green", "blue"), components))
    return tuple(_evaluate(expr, context) for expr in COLOR_EXPRESSIONS)


def transform(points, operation, amount=0.0):
    if operation not in OPERATIONS:
        raise ValueError("Unknown operation")
    if not points or any(len(p) != 3 for p in points):
        raise ValueError("Select UV points")
    if not math.isfinite(amount) or any(not math.isfinite(v) for p in points for v in p):
        raise ValueError("Nonfinite input")
    if operation in ("scale", "scale_u", "scale_v", "snap_u", "snap_v") and amount <= 0:
        raise ValueError("Scale must be positive; use explicit mirror instead")
    if operation in ("scale", "scale_u", "scale_v") and amount == 1 or operation == "rotate" and amount % 360 == 0:
        return [tuple(p) for p in points]
    min_u, max_u = min(p[0] for p in points), max(p[0] for p in points)
    min_v, max_v = min(p[1] for p in points), max(p[1] for p in points)
    common = dict(min_u=min_u, max_u=max_u, min_v=min_v, max_v=max_v,
                  center_u=(min_u + max_u) / 2.0, center_v=(min_v + max_v) / 2.0,
                  amount=amount, cosine=math.cos(math.radians(amount)),
                  sine=math.sin(math.radians(amount)))
    axis_u = sorted(set(p[0] for p in points)) if operation == "distribute_u" else []
    axis_v = sorted(set(p[1] for p in points)) if operation == "distribute_v" else []
    spacing_u = {value: min_u+(max_u-min_u)*i/(len(axis_u)-1) if len(axis_u)>1 else value for i,value in enumerate(axis_u)}
    spacing_v = {value: min_v+(max_v-min_v)*i/(len(axis_v)-1) if len(axis_v)>1 else value for i,value in enumerate(axis_v)}
    return [tuple(_evaluate(expr, dict(common, distributed_u=spacing_u.get(p[0],p[0]), distributed_v=spacing_v.get(p[1],p[1]), u=p[0], v=p[1], w=p[2],
                    snap_u=math.floor(p[0]*amount+0.5)/amount if operation == "snap_u" else p[0],
                    snap_v=math.floor(p[1]*amount+0.5)/amount if operation == "snap_v" else p[1]))
                  for expr in OPERATIONS[operation][1]) for p in points]


def emit_maxscript():
    lines = ["-- Generated from v1/edit_math.py; do not hand-edit this block.",
             "fn lsyUVColorFloats red green blue = (point3 " +
             " ".join("(" + e + ")" for e in COLOR_EXPRESSIONS) + ")",
             "fn lsyUVCalculate positions operation amount =", "(",
             '    if positions.count == 0 then throw "Select UV points."',
             '    if (findItem #(#scale,#scale_u,#scale_v,#snap_u,#snap_v) operation) > 0 and amount <= 0 then throw "Scale must be positive."',
             "    if (findItem #(#scale,#scale_u,#scale_v) operation) > 0 and amount == 1 then return positions",
             "    if operation == #rotate and (mod amount 360.0) == 0 then return positions",
             "    local min_u = positions[1].x", "    local max_u = min_u",
             "    local min_v = positions[1].y", "    local max_v = min_v",
             "    for p in positions do", "    (",
             "        if p.x < min_u do min_u = p.x", "        if p.x > max_u do max_u = p.x",
             "        if p.y < min_v do min_v = p.y", "        if p.y > max_v do max_v = p.y", "    )",
             "    local center_u = (min_u + max_u) / 2.0",
             "    local center_v = (min_v + max_v) / 2.0",
             "    local cosine = cos amount", "    local sine = sin amount",
             "    local levels_u = #()", "    local levels_v = #()",
             "    if operation == #distribute_u do (for p in positions do appendIfUnique levels_u p.x; sort levels_u)",
             "    if operation == #distribute_v do (for p in positions do appendIfUnique levels_v p.y; sort levels_v)",
             "    local result = #()", "    for p in positions do", "    (",
             "        local u = p.x", "        local v = p.y", "        local w = p.z",
             "        local distributed_u = u", "        local distributed_v = v",
             "        if levels_u.count > 1 do distributed_u = min_u+(max_u-min_u)*((findItem levels_u u)-1)/(levels_u.count-1)",
             "        if levels_v.count > 1 do distributed_v = min_v+(max_v-min_v)*((findItem levels_v v)-1)/(levels_v.count-1)",
             "        local snap_u = u", "        local snap_v = v",
             "        if operation == #snap_u do snap_u = (floor (u * amount + 0.5)) / amount",
             "        if operation == #snap_v do snap_v = (floor (v * amount + 0.5)) / amount",
             "        local q = case operation of", "        ("]
    for name, (_, expressions) in OPERATIONS.items():
        lines.append("            #" + name + ": point3 " +
                     " ".join("(" + expr + ")" for expr in expressions))
    lines += ['            default: throw "Unknown UV operation."', "        )",
              "        append result q", "    )", "    result", ")"]
    lines += ["fn lsyUVNormalizeSlot value =", "(", "    local text = toLower (value as string)"]
    for char in SLOT_STRIP:
        lines.append('    text = substituteString text "' + char + '" ""')
    lines += ["    text", ")", "fn lsyUVIsBaseSlot value =", "(",
              '    (findItem #(' + ','.join('"' + name + '"' for name in BASE_SLOT_NAMES) +
              ') (lsyUVNormalizeSlot value)) > 0', ")"]
    return "\n".join(lines) + "\n"
