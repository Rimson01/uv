"""UV repair calculations. No host access on import; density uses geometry triangulation."""
import math
import time
from collections import Counter


def triangulate(points):
    """Ear clip a simple planar 3D polygon; reject degeneracy/non-planarity."""
    if len(points)>256:raise ValueError('Density supports at most 256 corners per face')
    if len(points)<3: raise ValueError('A polygon needs at least three corners')
    if not all(math.isfinite(x) for p in points for x in p):raise ValueError('Nonfinite geometry')
    origin=points[0]
    p=[tuple(v[k]-origin[k] for k in range(3)) for v in points]
    normal=[sum(p[i][(k+1)%3]*p[(i+1)%len(p)][(k+2)%3]-p[i][(k+2)%3]*p[(i+1)%len(p)][(k+1)%3] for i in range(len(p))) for k in range(3)]
    size=max(math.dist(a,b) for a in p for b in p)
    length=math.sqrt(sum(x*x for x in normal))
    if size<=0 or length<=size*size*1e-12:raise ValueError('Degenerate geometry face')
    unit=[x/length for x in normal]
    if any(abs(sum(v[k]*unit[k] for k in range(3)))>size*1e-6 for v in p):raise ValueError('Non-planar polygon is unsupported; triangulate the source explicitly')
    drop=max(range(3),key=lambda k:abs(unit[k])); axes=[k for k in range(3) if k!=drop]
    q=[(v[axes[0]],v[axes[1]]) for v in p]
    def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    signed=sum(q[i][0]*q[(i+1)%len(q)][1]-q[(i+1)%len(q)][0]*q[i][1] for i in range(len(q)))
    sign=1 if signed>0 else -1; eps=size*size*1e-12
    def on_segment(a,b,c):
        return abs(cross(a,b,c))<=eps and min(a[0],b[0])-size*1e-12<=c[0]<=max(a[0],b[0])+size*1e-12 and min(a[1],b[1])-size*1e-12<=c[1]<=max(a[1],b[1])+size*1e-12
    for i in range(len(q)):
        for j in range(i+1,len(q)):
            if j==i+1 or (i==0 and j==len(q)-1):continue
            a,b=q[i],q[(i+1)%len(q)];c,d=q[j],q[(j+1)%len(q)]
            if (cross(a,b,c)*cross(a,b,d)<0 and cross(c,d,a)*cross(c,d,b)<0) or any((on_segment(a,b,c),on_segment(a,b,d),on_segment(c,d,a),on_segment(c,d,b))):
                raise ValueError('Self-intersecting or touching polygon')
    remaining=list(range(len(q))); result=[]
    while len(remaining)>3:
        for at in range(len(remaining)):
            a,b,c=remaining[at-1],remaining[at],remaining[(at+1)%len(remaining)]
            if sign*cross(q[a],q[b],q[c])<=eps:continue
            if any(all(sign*cross(q[x],q[y],q[k])>=-eps for x,y in ((a,b),(b,c),(c,a))) for k in remaining if k not in (a,b,c)):continue
            result.append((a,b,c));del remaining[at];break
        else:raise ValueError('Polygon cannot be triangulated without degeneracy')
    if sign*cross(*(q[i] for i in remaining))<=eps:raise ValueError('Degenerate final triangle')
    result.append(tuple(remaining));return result


def validate_native_triangles(corners, triangles):
    """Verify native corner coverage and internal edges, without choosing a diagonal."""
    if corners<3 or len(triangles)!=corners-2:
        raise ValueError('Native triangle count does not match polygon corners')
    edges=Counter(); oriented=Counter()
    for triangle in triangles:
        if len(triangle)!=3 or len(set(triangle))!=3 or any(i<0 or i>=corners for i in triangle):
            raise ValueError('Invalid native triangle corner')
        for a,b in zip(triangle,triangle[1:]+triangle[:1]):
            edges[tuple(sorted((a,b)))]+=1;oriented[a,b]+=1
    boundary={tuple(sorted((i,(i+1)%corners))) for i in range(corners)}
    if {edge for edge,count in edges.items() if count==1}!=boundary or any(count not in (1,2) for count in edges.values()):
        raise ValueError('Native triangles do not cover the polygon boundary')
    for (a,b),count in edges.items():
        if count==2 and (oriented[a,b]!=1 or oriented[b,a]!=1):
            raise ValueError('Native triangles have inconsistent internal winding')
    return triangles


def density(uv,world,faces,groups,width,height,triangles=None,partial=False,issues=None):
    if width<=0 or height<=0:raise ValueError('Image dimensions must be positive')
    records=[]
    deadline=time.monotonic()+5.0
    for group in groups:
        uv_area=0.;world_area=0.;zero_uv=0;zero_world=0
        try:
            for face in group:
                if time.monotonic()>deadline:raise ValueError('Density calculation exceeded the five-second budget')
                uv_ids,geom_ids=faces[face]
                if len(uv_ids)!=len(geom_ids):raise ValueError('UV/geometry corner mismatch')
                poly=[world[i] for i in geom_ids]
                tris=triangulate(poly) if triangles is None else validate_native_triangles(len(poly),triangles[face])
                for ordinal,(a,b,c) in enumerate(tris,1):
                    pa,pb,pc=(poly[i] for i in (a,b,c))
                    ab=[pb[k]-pa[k] for k in range(3)];ac=[pc[k]-pa[k] for k in range(3)]
                    area=math.sqrt(sum((ab[(k+1)%3]*ac[(k+2)%3]-ab[(k+2)%3]*ac[(k+1)%3])**2 for k in range(3)))*.5
                    ua,ub,uc=(uv[uv_ids[i]] for i in (a,b,c))
                    mapped=abs((ub[0]-ua[0])*(uc[1]-ua[1])-(ub[1]-ua[1])*(uc[0]-ua[0]))*.5
                    if not math.isfinite(area) or not math.isfinite(mapped):
                        raise ValueError('face=%d triangle=%d: nonfinite area' % (face+1,ordinal))
                    if area==0:
                        if mapped>0:raise ValueError('face=%d triangle=%d: world area=0 but UV area=%g' % (face+1,ordinal,mapped))
                        zero_world+=1;continue
                    if mapped==0:zero_uv+=1
                    world_area+=area;uv_area+=mapped
            if world_area<=0 or uv_area<=0:raise ValueError('Island density undefined: total world area=%g, UV area=%g' % (world_area,uv_area))
            records.append((math.sqrt(width*height*uv_area/world_area),uv_area,world_area))
            if issues is not None:issues.append('zero UV triangles=%d; zero world+UV triangles=%d' % (zero_uv,zero_world) if zero_uv or zero_world else '')
        except ValueError as exc:
            if not partial:raise
            records.append(None)
            if issues is not None:issues.append(str(exc))
    return records


def run_host():
    from pymxs import runtime as rt
    rt.lsyUVRepairResult=rt.undefined;rt.lsyUVRepairError=''
    try:
        snapshot=rt.lsyUVRepairInput
        uv=[(float(p.x),float(p.y),float(p.z)) for p in snapshot[0]]
        world=[(float(p.x),float(p.y),float(p.z)) for p in snapshot[1]]
        faces=[([int(i)-1 for i in f[0]],[int(i)-1 for i in f[1]]) for f in snapshot[2]]
        groups=[[int(i)-1 for i in group] for group in snapshot[3]]
        triangles=None
        if len(snapshot)>6:
            triangles=[[[int(i)-1 for i in triangle] for triangle in face] for face in snapshot[6]]
        issues=[]
        rows=density(uv,world,faces,groups,int(snapshot[4]),int(snapshot[5]),triangles,partial=True,issues=issues)
        rt.lsyUVRepairResult=rt.Array(*(rt.Array(*(tuple(row)+ (issue,) if row is not None else (0.,0.,0.,issue))) for row,issue in zip(rows,issues)))
    except Exception as exc:rt.lsyUVRepairError=str(exc)
