"""CPU reference fixtures for the embedded MAXScript Exact-island algorithm."""
import math


def components(faces):
    parent = list(range(len(faces)))
    def root(i):
        while parent[i] != i:
            i = parent[i]
        return i
    edges = {}
    owner = {}
    for f, (uv, geom) in enumerate(faces):
        if len(uv) != len(geom) or len(uv) < 3:
            raise ValueError('Invalid face')
        for u, g in zip(uv, geom):
            if u in owner and owner[u] != g:
                raise ValueError('UV index shared by unrelated geometry')
            owner[u] = g
        for j in range(len(uv)):
            k = (j+1) % len(uv)
            pair = sorted(((geom[j],uv[j]),(geom[k],uv[k])))
            if pair[0][0] == pair[1][0] or pair[0][1] == pair[1][1]:
                raise ValueError('Degenerate edge')
            key = tuple(pair)
            group = edges.setdefault(key, [])
            group.append(f)
            if len(group) > 2:
                raise ValueError('Nonmanifold edge')
            if len(group) == 2:
                parent[root(f)] = root(group[0])
    result = {}
    for i in range(len(faces)):
        result.setdefault(root(i), []).append(i)
    return list(result.values())


def face_key(corners):
    return min(tuple(corners[i:]+corners[:i]) for i in range(len(corners)))


def exact_solutions(reference, candidate, reference_faces, candidate_faces):
    """Translation+rotation only, entire point set and oriented face incidence."""
    if len(reference) != len(candidate) or len(reference_faces) != len(candidate_faces):
        return []
    base = reference[0]
    second = max(range(len(reference)), key=lambda i: math.dist(base,reference[i]))
    ar = tuple(reference[second][k]-base[k] for k in (0,1))
    far = math.hypot(*ar)
    if far < 1e-6:
        return []
    eps = max(1e-6,far*1e-5)
    keys = sorted(face_key(f) for f in reference_faces)
    solutions = set()
    for anchor in candidate:
        for other in candidate:
            ac = (other[0]-anchor[0],other[1]-anchor[1])
            size = math.hypot(*ac)
            if not size or abs(size-far) > eps:
                continue
            c = sum(ac[k]*ar[k] for k in (0,1))/(size*far)
            s = (ac[0]*ar[1]-ac[1]*ar[0])/(size*far)
            mapping = []
            for p in candidate:
                x,y = p[0]-anchor[0],p[1]-anchor[1]
                q = (base[0]+c*x-s*y,base[1]+s*x+c*y)
                choices = [(math.dist(q,r),i) for i,r in enumerate(reference) if i not in mapping]
                d,i = min(choices)
                if d > eps:
                    break
                mapping.append(i)
            if len(mapping) != len(candidate):
                continue
            mapped = sorted(face_key([mapping[i] for i in face]) for face in candidate_faces)
            if mapped == keys:
                solutions.add(tuple(mapping))
    return sorted(solutions)
