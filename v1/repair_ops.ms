-- Product commands share one immutable plan and one native SuperHold Undo group.
global lsyUVLastMeshSpace
global lsyUVStackPlan
global lsyUVDensityPlan
global lsyUVDensityData
global lsyUVRepairInput
global lsyUVRepairResult
global lsyUVRepairError
lsyUVStackPlan=undefined
lsyUVDensityPlan=undefined
lsyUVDensityData=undefined

fn lsyUVTopologyEqual a b =
(
    if a.count!=8 or b.count!=8 then return false
    for i=4 to 8 where a[i]!=b[i] do return false
    if a[1].count!=b[1].count or a[2].count!=b[2].count then return false
    for f=1 to a[2].count do
    (
        if a[2][f][3]!=b[2][f][3] then return false
        for field=1 to 2 do
        (
            if a[2][f][field].count!=b[2][f][field].count then return false
            for j=1 to a[2][f][field].count do
                if a[2][f][field][j]!=b[2][f][field][j] then return false
        )
    )
    true
)

fn lsyUVCommitCoordinates snapshot ids targets undoName =
(
    local node=snapshot[4]; local modifier=snapshot[5]
    if not lsyUVValid() then return false
    if lsyUVEditBlockedNode==node then throw "This target is blocked after an unverified rollback."
    lsyUVCheckWriteContext node modifier
    local live=lsyUVReadIslandSnapshot()
    if not (lsyUVSnapshotEqual live snapshot) then throw "UV/topology/time/material changed; calculate again."
    if ids.count!=targets.count then throw "Coordinate plan size mismatch."
    local seen=#{}; local changed=#()
    local expected=for field in snapshot collect field
    expected[1]=for point in snapshot[1] collect point
    for i=1 to ids.count do
    (
        local index=ids[i]; local point=targets[i]
        if index<1 or index>snapshot[1].count or seen[index] then throw "Invalid or repeated planned UV index."
        seen[index]=true
        if not (abs point.x<1e12 and abs point.y<1e12 and abs point.z<1e12) then throw "Invalid calculated UV."
        if point.z!=snapshot[1][index].z then throw "W must be preserved."
        expected[1][index]=point
        if (length (point-snapshot[1][index]))>0.00000001 do append changed i
    )
    if changed.count==0 then (lsyUVStatus "변경할 좌표가 없습니다."; return true)
    -- Legacy native setters capture full point state for each owned Hold.
    -- Bound worst-case Undo storage until the actual host is profiled.
    if snapshot[1].count*1.0*changed.count>2000000 then throw "Native Undo budget exceeded; reduce the selected vertices/islands."
    local failure=undefined
    local owned=false
    try
    (
        theHold.SuperBegin()
        owned=true
        with animate off
        (
            for changeSlot=1 to changed.count do
            (
                local i=changed[changeSlot]
                modifier.setVertexPosition2ByNode snapshot[7] ids[i] targets[i] true (changeSlot==changed.count) node
            )
        )
        live=lsyUVReadIslandSnapshot()
        if not (lsyUVSnapshotEqual live expected) then throw "Post-write snapshot mismatch (including unselected points/topology)."
        theHold.SuperAccept undoName
        owned=false
    ) catch (failure=getCurrentException())
    if failure!=undefined then
    (
        if owned do try (theHold.SuperCancel()) catch ()
        local restored=false
        try (restored=lsyUVSnapshotEqual (lsyUVReadIslandSnapshot()) snapshot) catch ()
        if not restored do
        (
            -- Fallback only if the full corner mapping is still identical.
            local safe=false
            try (safe=lsyUVTopologyEqual (lsyUVReadIslandSnapshot()) snapshot) catch ()
            if safe do
            (
                try
                (
                    undo off
                    (
                        with animate off
                        (
                            for index=1 to snapshot[1].count do
                                modifier.setVertexPosition2ByNode snapshot[7] index snapshot[1][index] false false node
                        )
                    )
                    restored=lsyUVSnapshotEqual (lsyUVReadIslandSnapshot()) snapshot
                ) catch (restored=false)
            )
        )
        if not restored do lsyUVEditBlockedNode=node
        try (modifier.UpdateView(); redrawViews()) catch ()
        throw ("Coordinate transaction failed; restored="+restored as string+" | "+failure)
    )
    lsyUVInvalidateAnalysis clearReference:true invalidateCoordinates:true
    modifier.UpdateView()
    redrawViews()
    lsyUVStatus (undoName+" 완료: "+changed.count as string+"점 / Undo 한 번")
    true
)

fn lsyUVRepairMaterialKey snapshot =
(
    local ids=#(); local key=#()
    for face in snapshot[2] do appendIfUnique ids face[3]
    sort ids
    for id in ids do
    (
        local result=lsyUVResolveID snapshot[4].material id
        append key id; append key result[3]; append key result[1]
        local path=if result[1]==undefined then undefined else lsyUVFilePath result[1].filename
        append key path
        append key (if path==undefined then undefined else getFileModDate path)
    )
    key
)

fn lsyUVPlanStack =
(
    lsyUVStackPlan=undefined
    LSYUVStack.applyPlan.enabled=false
    LSYUVStack.rows.items=#()
    LSYUVStack.info.text="변경 계산 중..."
    try
    (
        if lsyUVSimilarSnapshot==undefined or lsyUVSimilarMatches.count==0 then throw ("No usable Exact candidates. "+LSYUVSimilar.info.text+" | Reference/search again; ambiguous matches cannot be stacked automatically.")
        local snapshot=lsyUVReadIslandSnapshot()
        if not (lsyUVSnapshotEqual snapshot lsyUVSimilarSnapshot) then throw "Search is stale; capture/search again."
        local reference=snapshot[3][lsyUVReferenceIsland]
        local resolved=lsyUVResolveID snapshot[4].material reference[3][1]
        if resolved[1]==undefined then throw "Stack requires a resolved Bitmap for the reference Material ID."
        if (lsyUVFilePath resolved[1].filename)==undefined then throw "Reference texture file is missing."
        local ids=#(); local targets=#(); local used=#{}; local rows=#()
        for match in lsyUVSimilarMatches do
        (
            local fit=match[2]
            local maxError=0.0
            for i=1 to fit[1].count do
            (
                local index=fit[1][i]
                if reference[2][index] or used[index] then throw "Islands share UV points; independent Stack is unsafe."
                used[index]=true
                local p=snapshot[1][index]
                local q=[fit[3]*p.x-fit[4]*p.y+fit[5],fit[4]*p.x+fit[3]*p.y+fit[6],p.z]
                local r=snapshot[1][fit[2][i]]
                local delta=[q.x-r.x,q.y-r.y,0]
                if (length delta)>0.00001 then throw "Exact UV residual exceeds Stack tolerance."
                local pixels=length [delta.x*LSYUVStack.widthPx.value,delta.y*LSYUVStack.heightPx.value,0]
                if pixels>0.1 then throw "Stack residual exceeds 0.1 pixels at the entered resolution."
                maxError=amax maxError pixels
                append ids index; append targets q
            )
            append rows ("섬 "+match[1] as string+" → 기준 / 회전 "+(atan2 fit[4] fit[3]) as string+"° / Δ "+fit[5] as string+", "+fit[6] as string+" / 오차 "+maxError as string+"px")
        )
        for island in snapshot[3] do
            if (island[2]*used).numberSet>0 and (island[2]-used).numberSet>0 then throw "Stack touches UV points shared with another island."
        lsyUVStackPlan=#(snapshot,ids,targets,#stack,undefined,lsyUVRepairMaterialKey snapshot,LSYUVStack.widthPx.value,LSYUVStack.heightPx.value,lsyUVReferenceIsland)
        LSYUVStack.applyPlan.enabled=true
        LSYUVStack.rows.items=rows
        LSYUVStack.info.text="Stack 계산: "+lsyUVSimilarMatches.count as string+"섬 / "+ids.count as string+"점. 기준 불변. 적용 전 텍스처 영역 변경을 확인하세요."
        lsyUVStatus "Stack 변경 계산 완료. 회전+이동만 사용합니다. 좌표는 아직 변경하지 않았습니다."
        true
    ) catch (lsyUVStatus ("Stack 계산 오류: "+getCurrentException()); false)
)

fn lsyUVWorldCentimeters node =
(
    local cm=units.decodeValue "1cm"
    if cm<=0 then throw "Cannot resolve scene system units."
    local count=polyop.getNumVerts node.baseObject
    if count>200000 then throw "Density supports at most 200,000 geometry vertices."
    -- Density is translation invariant. Omit world translation BEFORE Point3
    -- multiplication to avoid losing small edges at a large scene offset.
    local full=node.objectTransform
    local linear=matrix3 full.row1 full.row2 full.row3 [0,0,0]
    for i=1 to count collect (((in coordsys local (polyop.getVert node.baseObject i))*linear)/cm)
)
fn lsyUVWorldEqual first second =
(
    if first.count!=second.count then return false
    for i=1 to first.count do if (length (first[i]-second[i]))>0.000001 then return false
    true
)
-- Read-only evaluated mesh: no convert/collapse/triangulate on the source node.
fn lsyUVNativeTriangles snapshot =
(
    local node=snapshot[4]
    local meshValue=snapshotAsMesh node
    local count=polyop.getNumVerts node.baseObject
    local channel=if snapshot[6]==0 then 1 else snapshot[6]
    if not (meshop.getMapSupport meshValue channel) then throw "Evaluated mesh has no selected UV channel."
    if meshValue.numverts!=count then throw "Evaluated mesh changes geometry vertex indexing; density correspondence is unsupported."
    if meshValue.numfaces>400000 then throw "Density mesh exceeds 400,000 triangles."
    -- snapshotAsMesh can return transformed coordinates. Validate one whole
    -- known node transform against ALL vertices; never remap individual indices.
    local basePoints=for i=1 to count collect (in coordsys local (polyop.getVert node.baseObject i))
    -- Meshop receives the standalone mesh value WITHOUT a node argument.
    -- Read its raw object-space vertices, not the context-sensitive getVert path.
    local meshPoints=for i=1 to count collect (meshop.getVert meshValue i)
    local transforms=#(matrix3 1)
    local labels=#("object-local")
    try (append transforms (inverse node.objectTransform); append labels "inverse objectTransform") catch ()
    try (append transforms (inverse node.transform); append labels "inverse node.transform") catch ()
    local usedGeometry=#{}
    for face in snapshot[2] do for index in face[2] do usedGeometry[index]=true
    local chosen=0
    local bestError=1e30
    local diagnostics=#()
    for slot=1 to transforms.count do
    (
        local valid=true; local maxError=0.0; local worst=0; local failures=0
        local transform=transforms[slot]
        local gain=amax (length transform.row1) (amax (length transform.row2) (length transform.row3))
        for i in usedGeometry do
        (
            local point=meshPoints[i]*transforms[slot]
            local difference=length (point-basePoints[i])
            if difference>maxError do (maxError=difference; worst=i)
            -- Float32 error bound includes transform cancellation at large offsets.
            local tolerance=0.00001+0.0000006*((length basePoints[i])+(length meshPoints[i])*gain+(length transform.row4))
            if difference>tolerance do (valid=false; failures+=1)
        )
        append diagnostics (labels[slot]+": failures="+failures as string+", max="+maxError as string+", worst vertex="+worst as string)
        if valid and maxError<bestError do (chosen=slot; bestError=maxError)
    )
    if chosen==0 then
        throw ("Density coordinate verification failed: "+diagnostics as string+" / used geometry="+usedGeometry.numberSet as string+". No coordinates written.")
    if lsyUVLastMeshSpace==undefined or lsyUVLastMeshSpace[1]!=node or lsyUVLastMeshSpace[2]!=labels[chosen] do
    (
        lsyUVLastMeshSpace=#(node,labels[chosen])
        lsyUVStatus ("Density 메시 좌표 확인: "+labels[chosen]+" / 전체 정점 오차 "+bestError as string)
    )
    local owners=for i=1 to count collect #{}
    local triangles=for f=1 to snapshot[2].count collect #()
    for f=1 to snapshot[2].count do
    (
        local baseCorners=polyop.getFaceVerts node.baseObject f
        local corners=snapshot[2][f][2]
        if baseCorners.count!=corners.count then throw "Base/UV polygon corners differ."
        for index in corners do
        (
            if (findItem baseCorners index)==0 then throw "Base/UV polygon geometry indices differ."
            owners[index][f]=true
        )
    )
    for t=1 to meshValue.numfaces do
    (
        local face=getFace meshValue t
        local ga=face.x as integer; local gb=face.y as integer; local gc=face.z as integer
        if ga<1 or gb<1 or gc<1 or ga>count or gb>count or gc>count then throw "Invalid evaluated triangle vertex."
        local matches=owners[ga]*owners[gb]*owners[gc]
        if matches.numberSet!=1 then throw "Evaluated triangle does not map to exactly one UV polygon."
        local f=(matches as array)[1]
        local corners=snapshot[2][f][2]
        local triple=#((findItem corners ga),(findItem corners gb),(findItem corners gc))
        local nativeMapFace=meshop.getMapFace meshValue channel t
        local nativeIndices=#(nativeMapFace.x as integer,nativeMapFace.y as integer,nativeMapFace.z as integer)
        for j=1 to 3 do
        (
            local nativeUV=meshop.getMapVert meshValue channel nativeIndices[j]
            local expected=snapshot[1][snapshot[2][f][1][triple[j]]]
            if (length [nativeUV.x-expected.x,nativeUV.y-expected.y,0])>0.000001 then throw "Evaluated UV corners differ from Unwrap snapshot."
        )
        append triangles[f] triple
    )
    triangles
)
fn lsyUVTrianglesEqual first second =
(
    if first.count!=second.count then return false
    for f=1 to first.count do
    (
        if first[f].count!=second[f].count then return false
        for t=1 to first[f].count do
            if not (lsyUVSameIndices first[f][t] second[f][t]) then return false
    )
    true
)

fn lsyUVDensityRead =
(
    local snapshot=lsyUVReadIslandSnapshot()
    local selected=lsyUVSelectedFaces()
    if selected==undefined or selected.count==0 then throw "Select faces or vertices of the islands to measure."
    local groups=#(); local slots=#()
    for i=1 to snapshot[3].count do
    (
        local hit=false
        for face in selected where (findItem snapshot[3][i][1] face)>0 do hit=true
        if hit do (append groups snapshot[3][i][1]; append slots i)
    )
    if groups.count==0 then throw "No selected islands."
    local world=lsyUVWorldCentimeters snapshot[4]
    local triangles=lsyUVNativeTriangles snapshot
    lsyUVRepairInput=#(snapshot[1],world,snapshot[2],groups,LSYUVTexel.widthPx.value,LSYUVTexel.heightPx.value,triangles)
    lsyUVRunDensityMath()
    if lsyUVRepairResult==undefined then throw lsyUVRepairError
    #(snapshot,world,slots,lsyUVRepairResult,LSYUVTexel.widthPx.value,LSYUVTexel.heightPx.value,triangles)
)
fn lsyUVDensityGet copyReference:false =
(
    lsyUVDensityPlan=undefined
    LSYUVTexel.applyPlan.enabled=false
    LSYUVTexel.rows.items=#()
    LSYUVTexel.info.text="변경 계산 중..."
    try
    (
        local data=lsyUVDensityRead()
        local totalUV=0.0; local totalWorld=0.0; local rows=#(); local invalid=0
        for i=1 to data[4].count do
        (
            if data[4][i][1]<=0 then
            (
                invalid+=1
                append rows ("섬 "+data[3][i] as string+": N/A / "+data[4][i][4])
            )
            else
            (
                totalUV+=data[4][i][2]; totalWorld+=data[4][i][3]
                append rows ("섬 "+data[3][i] as string+": "+data[4][i][1] as string+" px/cm"+(if data[4][i][4]=="" then "" else " / "+data[4][i][4]))
            )
        )
        LSYUVTexel.rows.items=rows
        if totalWorld<=0 then throw "All selected islands have undefined density. See N/A face/triangle details."
        local aggregate=sqrt (data[5]*1.0*data[6]*totalUV/totalWorld)
        if copyReference do
        (
            if invalid>0 then throw "Reference copy requires all selected islands to have valid density. Exclude N/A islands."
            if aggregate<0.000001 or aggregate>1000000000 then throw "Reference density is outside the supported target range."
            LSYUVTexel.targetDensity.value=aggregate
        )
        lsyUVDensityData=data
        LSYUVTexel.rows.items=rows
        LSYUVTexel.info.text="Raw UV · N/A "+invalid as string+"섬 / 유효 섬 면적 기준 "+aggregate as string+" px/cm. 입력 해상도는 모든 섬에 동일하게 적용됩니다."
        lsyUVStatus (if copyReference then "밀도 참조값을 목표 px/cm에 복사했습니다." else "밀도 조회 완료. 좌표는 변경하지 않았습니다.")
        true
    ) catch (lsyUVStatus ("밀도 조회 오류: "+getCurrentException()); false)
)
fn lsyUVPlanDensity =
(
    lsyUVDensityPlan=undefined
    LSYUVTexel.applyPlan.enabled=false
    LSYUVTexel.rows.items=#()
    LSYUVTexel.info.text="변경 계산 중..."
    try
    (
        local data=lsyUVDensityRead(); local snapshot=data[1]
        local ids=#(); local targets=#(); local used=#{}; local rows=#()
        for i=1 to data[3].count do
        (
            local island=snapshot[3][data[3][i]]
            if data[4][i][1]<=0 then throw ("섬 "+data[3][i] as string+" 밀도 적용 불가: "+data[4][i][4])
            local amount=LSYUVTexel.targetDensity.value/data[4][i][1]
            local indices=island[2] as array
            local points=for index in indices collect snapshot[1][index]
            local scaled=lsyUVCalculate points #scale amount
            for j=1 to indices.count do
            (
                if used[indices[j]] then throw "Selected islands share UV points; density scaling is ambiguous."
                used[indices[j]]=true
                append ids indices[j]; append targets scaled[j]
            )
            append rows ("섬 "+data[3][i] as string+": "+data[4][i][1] as string+" → "+LSYUVTexel.targetDensity.value as string+" px/cm / ×"+amount as string+(if data[4][i][4]=="" then "" else " / "+data[4][i][4]))
        )
        for i=1 to snapshot[3].count where (findItem data[3] i)==0 do
            if (snapshot[3][i][2]*used).numberSet>0 then throw "Density change would move another island's shared UV point."
        -- Check the rounded host Point3 targets, not only the ideal scale ratio.
        local predicted=for point in snapshot[1] collect point
        for i=1 to ids.count do predicted[ids[i]]=targets[i]
        local groups=for slot in data[3] collect snapshot[3][slot][1]
        lsyUVRepairInput=#(predicted,data[2],snapshot[2],groups,data[5],data[6],data[7])
        lsyUVRunDensityMath()
        if lsyUVRepairResult==undefined then throw lsyUVRepairError
        for row in lsyUVRepairResult do
        (
            if row[1]<=0 then throw row[4]
            if abs (row[1]/LSYUVTexel.targetDensity.value-1)>0.001 then throw "Rounded UV coordinates cannot achieve the target density within 0.1%."
        )
        lsyUVDensityPlan=#(snapshot,ids,targets,#density,data[2],lsyUVRepairMaterialKey snapshot,data[5],data[6],LSYUVTexel.targetDensity.value,data[7])
        LSYUVTexel.applyPlan.enabled=true
        LSYUVTexel.rows.items=rows
        LSYUVTexel.info.text="Density 변경 계산 완료. 선택이 닿는 전체 섬을 각각 중심 기준으로 확대/축소합니다. 텍스처 패턴 크기가 달라집니다."
        lsyUVStatus "Density 변경 계산 완료. 적용 버튼에서 한 번 Undo로 반영합니다."
        true
    ) catch (lsyUVStatus ("밀도 계산 오류: "+getCurrentException()); false)
)
fn lsyUVApplyRepairPlan kind =
(
    try
    (
        if kind!=#stack and kind!=#density then throw "Unknown repair operation."
        local panel=if kind==#stack then LSYUVStack else LSYUVTexel
        local plan=if kind==#stack then lsyUVStackPlan else lsyUVDensityPlan
        if plan==undefined then throw "Calculate this tool's change first."
        if plan[4]!=kind then throw "Repair plan belongs to a different operation."
        if not lsyUVValid() then return false
        if plan[4]==#density do
            if LSYUVTexel.targetDensity.value!=plan[9] then throw "Target density changed; calculate again."
        if panel.widthPx.value!=plan[7] or panel.heightPx.value!=plan[8] then throw "Resolution changed; calculate again."
        if not (lsyUVKeyEqual plan[6] (lsyUVRepairMaterialKey plan[1])) then throw "Material/texture changed; calculate again."
        if plan[5]!=undefined do
        (
            if not (lsyUVWorldEqual plan[5] (lsyUVWorldCentimeters plan[1][4])) then throw "World geometry/system units changed; calculate again."
            if not (lsyUVTrianglesEqual plan[10] (lsyUVNativeTriangles plan[1])) then throw "Native triangulation changed; calculate again."
        )
        local name=if plan[4]==#stack then "LSY Exact Stack" else "LSY Texel Density"
        local committed=lsyUVCommitCoordinates plan[1] plan[2] plan[3] name
        if committed do
        (
            if kind==#stack then lsyUVStackPlan=undefined else lsyUVDensityPlan=undefined
            panel.applyPlan.enabled=false
            if plan[4]==#stack do
            (
                -- Retain the reference only after proving its coordinates untouched.
                local kept=false
                try
                (
                    local live=lsyUVReadIslandSnapshot()
                    local slot=plan[9]
                    local unchanged=lsyUVTopologyEqual live plan[1]
                    for index in plan[1][3][slot][2] do
                        if (length (live[1][index]-plan[1][1][index]))>0.00000001 do unchanged=false
                    if unchanged do
                    (
                        lsyUVReferenceSnapshot=live
                        lsyUVReferenceIsland=slot
                        lsyUVSimilarSnapshot=undefined
                        lsyUVSimilarFaces=#{}
                        lsyUVSimilarMatches=#()
                        LSYUVSimilar.info.text="Stack 후 기준 유지 · 다시 검색해서 다음 작업을 계산하세요."
                        kept=true
                    )
                ) catch ()
                LSYUVStack.info.text=if kept then "Stack 적용 후 기준을 유지했습니다. 다음 Stack은 다시 검색하세요." else "Stack 적용 완료. 다음 작업의 기준 섬을 다시 지정하세요."
            )
        )
        committed
    ) catch (lsyUVStatus ("적용 오류: "+getCurrentException()); false)
)
