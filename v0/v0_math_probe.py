"""Dependency-free P4 mathematical checks; this does not access a Max scene."""

from __future__ import print_function

import math


def density_px_per_cm(world_area_cm2, uv_area, width, height):
    if world_area_cm2 <= 0 or uv_area < 0 or width <= 0 or height <= 0:
        raise ValueError("Invalid area or texture resolution")
    return math.sqrt(uv_area * width * height / world_area_cm2)


def align_rigid(source, target):
    """Correspondence is given; fit translation and rotation, then report max error."""
    if len(source) != len(target) or len(source) < 2:
        raise ValueError("Expected paired 2D points")
    count = len(source)
    sc = (sum(p[0] for p in source) / count, sum(p[1] for p in source) / count)
    tc = (sum(p[0] for p in target) / count, sum(p[1] for p in target) / count)
    dot = 0.0
    cross = 0.0
    for p, q in zip(source, target):
        px, py = p[0] - sc[0], p[1] - sc[1]
        qx, qy = q[0] - tc[0], q[1] - tc[1]
        dot += px * qx + py * qy
        cross += px * qy - py * qx
    angle = math.atan2(cross, dot)
    c, s = math.cos(angle), math.sin(angle)
    errors = []
    for p, q in zip(source, target):
        x, y = p[0] - sc[0], p[1] - sc[1]
        fit = (c * x - s * y + tc[0], s * x + c * y + tc[1])
        errors.append(math.hypot(fit[0] - q[0], fit[1] - q[1]))
    return angle, max(errors)


def run():
    square = density_px_per_cm(10000.0, 1.0, 1024, 1024)
    non_square = density_px_per_cm(10000.0, 1.0, 2048, 1024)
    assert math.isclose(square, 10.24, rel_tol=1e-12)
    assert math.isclose(non_square, 14.481546878700494, rel_tol=1e-12)
    assert math.isclose(density_px_per_cm(10000, 0.25, 1024, 1024), 5.12)
    assert math.isclose(density_px_per_cm(20000, 1, 1024, 1024), 7.240773439350247)

    shape = [(0.0, 0.0), (2.0, 0.0), (2.0, 1.0), (0.7, 1.0), (0.7, 2.0)]
    rad = math.radians(37.0)
    rotated = [(math.cos(rad) * x - math.sin(rad) * y + 3,
                math.sin(rad) * x + math.cos(rad) * y - 2) for x, y in shape]
    angle, error = align_rigid(shape, rotated)
    assert abs(angle - rad) < 1e-12 and error < 1e-12

    different = list(rotated)
    different[3] = (different[3][0] + 0.2, different[3][1])
    _, negative_error = align_rigid(shape, different)
    assert negative_error > 0.01

    print("P4 PASS: 37-degree rigid alignment, negative shape, square/non-square density")
    print("  density 1024x1024: {:.8f} px/cm".format(square))
    print("  density 2048x1024: {:.8f} px/cm".format(non_square))
    print("  positive max error: {:.12f}; negative max error: {:.6f}".format(error, negative_error))


if __name__ == "__main__":
    run()
