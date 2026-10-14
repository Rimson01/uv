-- Read-only UV snapshot and edge-connected islands. No geometry writes.
global lsyUVReferenceSnapshot
global lsyUVReferenceIsland
global lsyUVSimilarSnapshot
global lsyUVSimilarFaces
global lsyUVSimilarMatches
-- A reload must never reuse snapshots captured by a previous implementation.
lsyUVReferenceSnapshot=undefined
lsyUVReferenceIsland=undefined
lsyUVSimilarSnapshot=undefined
lsyUVSimilarFaces=#{}
lsyUVSimilarMatches=#()
fn lsyUVCompareEdgeRows a b = (stricmp a[1] b[1])
fn lsyUVReadIslandSnapshot =
(
    if not lsyUVValid() then throw "Bind one active Unwrap first."
    local node = lsyUVNode
    local modifier = lsyUVMod
    if classOf node.baseObject != Editable_Poly or node.modifiers.count != 1 then throw "Analysis requires Editable Poly + one Unwrap."
    if modifier.getVC() then throw "Use a UV channel."
    local count = modifier.numberPolygonsByNode node
    if count != polyop.getNumFaces node.baseObject then throw "UV/base face counts differ."
    if count > 20000 then throw "Initial analysis supports at most 20,000 faces."
    local vertexCount = modifier.numberVerticesByNode node
    if vertexCount > 100000 then throw "Initial analysis supports at most 100,000 UV points."
    local points = for i=1 to vertexCount collect (modifier.GetVertexPositionByNode currentTime i node)
    for p in points do if not (abs p.x < 1000000000000.0 and abs p.y < 1000000000000.0 and abs p.z < 1000000000000.0) then throw "Invalid UV coordinate."
    local faces = #()
    local edges = #()
    local owners = for i=1 to vertexCount collect 0
    local parent = for i=1 to count collect i
    for f=1 to count do
    (
        local uv = #()
        local geom = #()
        local corners = modifier.numberPointsInFaceByNode f node
        if corners < 3 then throw "Degenerate UV face."
        for j=1 to corners do
        (
            local u = modifier.getVertexIndexFromFaceByNode f j node
            local g = modifier.getVertexGeomIndexFromFaceByNode f j node
            if u < 1 or u > vertexCount or g < 1 then throw "Invalid corner mapping."
            if owners[u] != 0 and owners[u] != g then throw "One UV index is shared by unrelated geometry; analysis blocked."
            owners[u] = g
            append uv u
            append geom g
        )
        append faces #(uv,geom,polyop.getFaceMatID node.baseObject f)
        for j=1 to corners do
        (
            local next = if j == corners then 1 else j+1
            local ga=geom[j]; local gb=geom[next]
            local ua=uv[j]; local ub=uv[next]
            if ga==gb or ua==ub then throw "Degenerate edge."
            if ga>gb do (local t=ga; ga=gb; gb=t; t=ua; ua=ub; ub=t)
            local key=ga as string+":"+gb as string+":"+ua as string+":"+ub as string
            append edges #(key,f)
        )
    )
    qsort edges lsyUVCompareEdgeRows
    if edges.count > 1 do for i=2 to edges.count where edges[i][1]==edges[i-1][1] do
    (
        if i>2 and edges[i][1]==edges[i-2][1] then throw "Nonmanifold UV edge; analysis blocked."
        local a=edges[i-1][2]; local b=edges[i][2]
        while parent[a]!=a do a=parent[a]
        while parent[b]!=b do b=parent[b]
        if a!=b do parent[b]=a
    )
    local roots=#(); local islands=#()
    for f=1 to count do
    (
        local root=f
        while parent[root]!=root do root=parent[root]
        local slot=findItem roots root
        if slot==0 do (append roots root; append islands #(#(),#{},#()); slot=roots.count)
        append islands[slot][1] f
        for u in faces[f][1] do islands[slot][2][u]=true
        appendIfUnique islands[slot][3] faces[f][3]
    )
    #(points,faces,islands,node,modifier,modifier.getMapChannel(),currentTime,node.material)
)
fn lsyUVSnapshotEqual a b =
(
    if not (lsyUVTopologyEqual a b) then return false
    for i=1 to a[1].count do if (length (a[1][i]-b[1][i]))>0.00000001 then return false
    true
)
fn lsyUVIslandSeed snapshot =
(
    local selected=lsyUVSelectedFaces()
    if selected==undefined or selected.count==0 then throw "Select one reference island or a face in it."
    local slots=#()
    for i=1 to snapshot[3].count do
        for f in selected where (findItem snapshot[3][i][1] f)>0 do appendIfUnique slots i
    if slots.count!=1 then throw "Selection spans multiple islands; select one reference island."
    slots[1]
)
fn lsyUVFaceKey corners =
(
    local best=undefined
    for start=1 to corners.count do
    (
        local key=""
        for j=0 to corners.count-1 do key += (corners[1+mod (start-1+j) corners.count] as string)+":"
        if best==undefined or (stricmp key best)<0 do best=key
    )
    best
)
fn lsyUVIslandArea snapshot island =
(
    local area=0.0
    for f in island[1] do
    (
        local ids=snapshot[2][f][1]
        local signed=0.0
        for j=1 to ids.count do
        (
            local next=if j==ids.count then 1 else j+1
            local a=snapshot[1][ids[j]]; local b=snapshot[1][ids[next]]
            signed+=a.x*b.y-a.y*b.x
        )
        area+=abs signed*0.5
    )
    area
)
fn lsyUVSameIndices first second =
(
    if first.count!=second.count then return false
    for i=1 to first.count do if first[i]!=second[i] then return false
    true
)
fn lsyUVExactCandidate snapshot refIndex candidateIndex deadline:undefined preserveDirection:false =
(
    if deadline==undefined do deadline=timeStamp()+5000
    local ref=snapshot[3][refIndex]; local candidate=snapshot[3][candidateIndex]
    local rids=ref[2] as array; local cids=candidate[2] as array
    if rids.count!=cids.count or ref[1].count!=candidate[1].count then return #(#different,0,undefined)
    if rids.count>128 then return #(#unjudged,0,undefined)
    if ref[3].count!=1 or candidate[3].count!=1 or ref[3][1]!=candidate[3][1] then return #(#filtered,0,undefined)
    local points=snapshot[1]
    local base=points[rids[1]]
    local second=0; local far=0.0
    for i=2 to rids.count do
    (
        local d=length ([points[rids[i]].x-base.x,points[rids[i]].y-base.y,0])
        if d>far do (far=d; second=i)
    )
    if far<0.000001 then return #(#degenerate,0,undefined)
    local ar=points[rids[second]]-base; ar.z=0
    local tolerance=amax 0.000001 (far*0.00001)
    if (lsyUVIslandArea snapshot ref)<=tolerance*tolerance or (lsyUVIslandArea snapshot candidate)<=tolerance*tolerance then return #(#degenerate,0,undefined)
    -- Coincident independent corners need graph backtracking; do not invent a unique match.
    for ids in #(rids,cids) do for i=1 to ids.count-1 do for j=i+1 to ids.count do
        if j<=ids.count and (length ([points[ids[i]].x-points[ids[j]].x,points[ids[i]].y-points[ids[j]].y,0]))<=tolerance then return #(#unjudged,0,undefined)
    local refKeys=for f in ref[1] collect (lsyUVFaceKey snapshot[2][f][1])
    local solutions=#(); local errors=#(); local fits=#(); local attempts=0
    for anchor in cids do for other in cids where other!=anchor do
    (
        if timeStamp()>deadline then return #(#unjudged,0,undefined)
        local ac=points[other]-points[anchor]; ac.z=0
        local size=length ac
        if abs (size-far)<=tolerance do
        (
            if timeStamp()>deadline then return #(#unjudged,0,undefined)
            attempts+=1
            if attempts>512 then return #(#unjudged,0,undefined)
            local cosine=(ac.x*ar.x+ac.y*ar.y)/(size*far)
            local sine=(ac.x*ar.y-ac.y*ar.x)/(size*far)
            local used=#{}; local mapping=for i=1 to cids.count collect 0
            local good=true; local error=0.0
            for u in cids while good do
            (
                if timeStamp()>deadline then return #(#unjudged,0,undefined)
                local delta=points[u]-points[anchor]
                local q=[base.x+cosine*delta.x-sine*delta.y,base.y+sine*delta.x+cosine*delta.y,0]
                local nearest=0; local distance=tolerance
                for r in rids where not used[r] do
                (
                    local d=length (q-[points[r].x,points[r].y,0])
                    if d<=distance do (nearest=r; distance=d)
                )
                if nearest==0 then good=false
                else (used[nearest]=true; mapping[findItem cids u]=nearest; error=amax error distance)
            )
            if good do
            (
                local keys=for faceKey in refKeys collect faceKey
                for f in candidate[1] while good do
                (
                    local mappedCorners=for u in snapshot[2][f][1] collect mapping[findItem cids u]
                    local slot=findItem keys (lsyUVFaceKey mappedCorners)
                    if slot==0 then good=false else deleteItem keys slot
                )
            )
            if good do
            (
                local repeated=false
                for solution in solutions do if lsyUVSameIndices solution mapping do repeated=true
                if not repeated do
                (
                    append solutions mapping; append errors error
                    append fits #(cids,mapping,cosine,sine,base.x-cosine*points[anchor].x+sine*points[anchor].y,base.y-sine*points[anchor].x-cosine*points[anchor].y)
                )
            )
        )
    )
    if solutions.count==0 then #(#different,0,undefined)
    else if solutions.count>1 then
    (
        if preserveDirection do
        (
            local eligible=#()
            for i=1 to fits.count do
                if abs fits[i][4]<=0.000001 and abs (fits[i][3]-1)<=0.000001 do append eligible i
            if eligible.count==1 do
            (
                local slot=eligible[1]
                local fit=fits[slot]
                local offset=points[fit[2][1]]-points[fit[1][1]]
                local residual=0.0
                for i=1 to fit[1].count do
                (
                    local delta=points[fit[1][i]]+offset-points[fit[2][i]]
                    residual=amax residual (length [delta.x,delta.y,0])
                )
                if residual<=tolerance do
                    return #(#exact,1,residual,#(fit[1],fit[2],1.0,0.0,offset.x,offset.y),#preserveDirection)
            )
        )
        #(#ambiguous,solutions.count,(amin errors))
    )
    else #(#exact,1,errors[1],fits[1])
)
fn lsyUVCaptureReference =
(
    lsyUVInvalidateAnalysis clearReference:true
    try
    (
        local snapshot=lsyUVReadIslandSnapshot()
        local slot=lsyUVIslandSeed snapshot
        if snapshot[3][slot][3].count!=1 then throw "Reference island contains mixed Material IDs."
        lsyUVReferenceSnapshot=snapshot
        lsyUVReferenceIsland=slot
        lsyUVSimilarSnapshot=undefined
        lsyUVSimilarFaces=#{}
        LSYUVSimilar.info.text="기준 섬: 면 "+snapshot[3][slot][1].count as string+" / 점 "+snapshot[3][slot][2].numberSet as string+" / ID "+snapshot[3][slot][3][1] as string
        lsyUVStatus "기준 섬 지정 완료. 좌표/재질이 바뀌면 다시 지정하세요."
        true
    )
    catch (lsyUVStatus ("기준 섬 오류: "+getCurrentException()); false)
)
fn lsyUVFindSimilar =
(
    lsyUVInvalidateAnalysis()
    try
    (
        if lsyUVReferenceSnapshot==undefined then throw "Capture a reference island first."
        local snapshot=lsyUVReadIslandSnapshot()
        if not (lsyUVSnapshotEqual snapshot lsyUVReferenceSnapshot) then throw "UV/time/channel/material changed; capture reference again."
        local seed=lsyUVReferenceIsland
        local results=#(); local selected=#{}; local exact=0; local ambiguous=0; local unjudged=0; local degenerate=0; local different=0; local filtered=0
        local start=timeStamp()
        for i=1 to snapshot[3].count where i!=seed do
        (
            if (timeStamp()-start)>5000 then
            (
                append results ("섬 "+i as string+": 시간 제한 / 미판정")
                unjudged+=1
            )
            else
            (
                local result=lsyUVExactCandidate snapshot seed i deadline:(start+5000) preserveDirection:LSYUVSimilar.keepDirection.checked
                case result[1] of
                (
                    #different: different+=1
                    #filtered: filtered+=1
                    #exact: (append lsyUVSimilarMatches #(i,result[4],result[3]); exact+=1; for f in snapshot[3][i][1] do selected[f]=true; append results ("섬 "+i as string+": Exact / 오차 "+result[3] as string+(if result.count>=5 then " / 대칭: 방향 유지" else "")))
                    #ambiguous: (ambiguous+=1; append results ("섬 "+i as string+": 대칭 대응 "+result[2] as string+"개 / 자동 선택 제외"))
                    #degenerate: (degenerate+=1; append results ("섬 "+i as string+": 퇴화 / 적용 제외"))
                    #unjudged: (unjudged+=1; append results ("섬 "+i as string+": 계산 제한 / 미판정"))
                )
            )
        )
        lsyUVSimilarSnapshot=snapshot
        lsyUVSimilarFaces=selected
        LSYUVSimilar.results.items=results
        LSYUVSimilar.info.text="Exact "+exact as string+" / 대칭 "+ambiguous as string+" / 미판정 "+unjudged as string+" / 퇴화 "+degenerate as string+" / 불일치 "+different as string+" / ID 제외 "+filtered as string
        lsyUVStatus ("유사 섬 검색: "+LSYUVSimilar.info.text+" | 같은 ID·크기, 회전+이동만 비교 / 최대 128점·5초")
        true
    )
    catch (local reason=getCurrentException(); lsyUVInvalidateAnalysis(); lsyUVStatus ("유사 섬 검색 오류: "+reason); false)
)
fn lsyUVSelectSimilarResults =
(
    try
    (
        if lsyUVSimilarSnapshot==undefined then throw "Run the search first."
        if lsyUVSimilarFaces.numberSet==0 then
        (
            lsyUVStatus ("선택 가능한 Exact 후보 없음: "+LSYUVSimilar.info.text)
            return false
        )
        local live=lsyUVReadIslandSnapshot()
        if not (lsyUVSnapshotEqual live lsyUVSimilarSnapshot) then throw "Snapshot changed; search again."
        local modifier=lsyUVMod
        local node=lsyUVNode
        local original=modifier.getSelectedFacesByNode node
        undo "LSY Similar island selection" on
        (
            try
            (
                modifier.selectFacesByNode lsyUVSimilarFaces node
                if not (lsyUVSameSelection (modifier.getSelectedFacesByNode node) lsyUVSimilarFaces) then throw "Similar face selection readback mismatch."
            )
            catch (modifier.selectFacesByNode original node; throw())
        )
        modifier.UpdateView()
        redrawViews()
        lsyUVStatus "Exact 후보 면을 선택했습니다. 기준 섬 좌표는 변경하지 않았습니다."
        true
    )
    catch (lsyUVStatus ("결과 선택 오류: "+getCurrentException()); false)
)
