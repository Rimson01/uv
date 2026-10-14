/* Developer regression runner: run in 3ds Max, not ordinary Python.
   Loads only helper definitions, never creates the Workbench UI or edits a scene.
   Requires the repository's tests/ and v1/ directories together. */
global lsyUVMod
global lsyUVResolveID
global lsyUVDropdownIndex
global lsyUVMapAtDropdown
global lsyUVMapIndex
global lsyUVFormatIDs
global lsyUVBaseMap
global lsyUVColorFloats
global lsyUVCalculate
global lsyUVNormalizeSlot
global lsyUVRestoreBackgroundState
global lsyUVIslandFromEdges
global lsyUVIsBaseSlot
global lsyUVExactCandidate
global lsyUVSameIndices
global lsyUVTopologyEqual
global lsyUVEditorReady
global lsyUVSnapshotEqual

(
    local root = getFilenamePath (getSourceFileName())
    local path = root + "..\\v1\\LSY_UV_Workbench.ms"
    local stream = openFile path
    if stream == undefined then throw "Workbench source not found."
    local code = ""
    while not eof stream do code += (readLine stream) + "\n"
    close stream

    fn loadHelperRange code first last =
    (
        local start = findString code first
        local finish = findString code last
        if start == undefined or finish == undefined then throw "Helper range not found."
        execute (substring code start (finish - start))
    )
    loadHelperRange code "fn lsyUVFormatIDs " "fn lsyUVMaterial "
    loadHelperRange code "-- BEGIN SHARED EDIT MATH" "-- END SHARED EDIT MATH"
    loadHelperRange code "fn lsyUVDropdownIndex " "fn lsyUVBackgroundRestore "

    loadHelperRange code "-- BEGIN UV CONNECTIVITY" "-- END UV CONNECTIVITY"
    loadHelperRange code "fn lsyUVTopologyEqual " "fn lsyUVCommitCoordinates "
    loadHelperRange code "fn lsyUVEditorReady " "fn lsyUVPrepareCustomBackground "
    loadHelperRange code "fn lsyUVSnapshotEqual " "fn lsyUVIslandSeed "
    loadHelperRange code "fn lsyUVFaceKey " "fn lsyUVCaptureReference "

    loadHelperRange code "fn lsyUVRestoreBackgroundState " "-- Close the previous instance"

    struct LSYUVRestoreFixture
    (
        texMapList = #(),
        shown = true,
        autoBG = false,
        current = 1,
        brokenMapList = false,
        fn numberMaps = (if brokenMapList then throw "Stale map list" else texMapList.count + 1),
        fn getCurrentMap = current,
        fn SetCurrentMap index = (current = index),
        fn getShowMap = shown,
        fn setShowMap value = (shown = value),
        fn getAutoBackground = autoBG,
        fn setAutoBackground value = (autoBG = value),
        fn updateMap = true
    )

    struct LSYUVListFixture
    (
        texMapList = #(),
        fn numberMaps = texMapList.count + 1,
        fn addMap image = (appendIfUnique texMapList image)
    )
    struct LSYUVReadyFixture
    (
        mapCount= -6,
        fn numberMaps = mapCount,
        fn numberMatIDs = 5
    )
    local previousMod = lsyUVMod
    local count = 0
    fn require condition message = (if not condition then throw message)
    try
    (
        lsyUVMod=LSYUVReadyFixture()
        require (not lsyUVEditorReady()) "Negative map count must be treated as unavailable Editor."
        lsyUVMod.mapCount=9
        require (lsyUVEditorReady()) "Positive Editor control counts should permit display inspection."
        lsyUVMod=previousMod
        count+=2
        local pointControl=bezier_point3()
        require (not (isAnimated pointControl)) "Fresh point controller must be static."
        undo off
        (
            with animate on
            (
                at time 10 (pointControl.value=[1,2,3])
            )
        )
        require (isAnimated pointControl) "Animation dispatch must work on an actual point controller."
        count+=2
        -- Read-only optional smoke check on the user's selected object.
        if selection.count==1 do
        (
            local meshSample=snapshotAsMesh selection[1]
            if meshSample.numverts>0 do
            (
                local raw=in coordsys world (meshop.getVert meshSample 1)
                local shifted=in coordsys (transMatrix [1000,-1750,24000]) (meshop.getVert meshSample 1)
                require ((length (raw-shifted))<0.000001) "Standalone meshop vertex read must not inherit node/reference coordinates."
                count+=1
            )
        )
        local snapshotA=#(#([0,0,0]),#(#(#(1),#(1),2)),#(),"node","modifier",0,0,"materialA")
        local snapshotB=#(#([0,0,0]),#(#(#(1),#(1),2)),#(),"node","modifier",0,0,"materialA")
        require (lsyUVSnapshotEqual snapshotA snapshotB) "Identical snapshots should match."
        snapshotB[8]="materialB"
        require (not (lsyUVSnapshotEqual snapshotA snapshotB)) "Replacing root material must invalidate analysis."
        snapshotB[8]="materialA"; snapshotB[1][1]=[0,0,1]
        require (not (lsyUVSnapshotEqual snapshotA snapshotB)) "W changes must invalidate analysis."
        count+=3
        local sourcePoints=#([0,0,0],[3,0,0],[2,1,0],[0,2,0])
        local allPoints=for p in sourcePoints collect p
        for p in sourcePoints do append allPoints [cos(37)*p.x-sin(37)*p.y+8,sin(37)*p.x+cos(37)*p.y-3,7]
        local sample=#(allPoints,#(#(#(1,2,3),#(1,2,3),1),#(#(1,3,4),#(1,3,4),1),#(#(5,6,7),#(5,6,7),1),#(#(5,7,8),#(5,7,8),1)),#(#(#(1,2),#{1..4},#(1)),#(#(3,4),#{5..8},#(1))),"node","mod",0,0,"mat")
        local exact=lsyUVExactCandidate sample 1 2
        require (exact[1]==#exact and exact.count==4) "Exact search must retain a unique rigid fit."
        local fit=exact[4]
        for i=1 to fit[1].count do
        (
            local p=allPoints[fit[1][i]]
            local target=[fit[3]*p.x-fit[4]*p.y+fit[5],fit[4]*p.x+fit[3]*p.y+fit[6],p.z]
            local expected=allPoints[fit[2][i]]
            require ((length [target.x-expected.x,target.y-expected.y,0])<0.00001 and target.z==7) "Stored fit must align UV and preserve W."
        )
        count+=1
        local square=#(#([0,0,0],[1,0,0],[1,1,0],[0,1,0],[8,-3,0],[9,-3,0],[9,-2,0],[8,-2,0]),#(#(#(1,2,3,4),#(1,2,3,4),1),#(#(5,6,7,8),#(5,6,7,8),1)),#(#(#(1),#{1..4},#(1)),#(#(2),#{5..8},#(1))),"node","mod",0,0,"mat")
        require ((lsyUVExactCandidate square 1 2)[1]==#ambiguous) "Square must be ambiguous by default."
        local kept=lsyUVExactCandidate square 1 2 preserveDirection:true
        require (kept[1]==#exact and kept[5]==#preserveDirection and abs kept[4][4]<0.000001) "Explicit direction policy must choose translation-only fit."
        count+=2
        local island = lsyUVIslandFromEdges 6 #(#(1,2),#(2,3),#(4,5),#(5,6)) #{2} #{1..6}
        require (island == #{1,2,3}) "UV seam islands must remain separate."
        require ((lsyUVIslandFromEdges 6 #(#(1,2),#(2,3)) #{} #{1..6}) == #{}) "Empty selection must stay empty."
        count += 2
        local same = bitmaptexture filename:"C:\\LSY_Restore.png"
        local fixture = LSYUVRestoreFixture brokenMapList:true
        local issues = lsyUVRestoreBackgroundState fixture #(same,3,false,true) #(same,true,false,14)
        require (issues.count == 0 and not fixture.shown and fixture.autoBG) "Equal-map restore must bypass stale map list."
        count += 1
        fixture = LSYUVRestoreFixture brokenMapList:true
        issues = lsyUVRestoreBackgroundState fixture #(same,3,false,true) #(undefined,true,false,14)
        require (issues.count == 1 and not fixture.shown and fixture.autoBG) "Map failure must not block independent flag restore."
        count += 1
        local a = bitmaptexture filename:"C:\\LSY_Test_A.png"
        local b = bitmaptexture filename:"C:\\LSY_Test_B.png"
        local c = bitmaptexture filename:"C:\\LSY_Test_C.png"
        local ma = standardMaterial()
        local mb = standardMaterial()
        local mc = standardMaterial()
        ma.diffuseMap = a; ma.diffuseMapEnable = true
        mb.diffuseMap = b; mb.diffuseMapEnable = true
        mc.diffuseMap = c; mc.diffuseMapEnable = true
        local multi = multiMaterial numsubs:3
        multi.materialIDList = #(2,7,42)
        multi.materialList = #(ma,mb,mc)
        local resolved = lsyUVResolveID multi 42
        require (resolved[1] == c) "Sparse material ID 42 mapped to wrong slot."
        count += 1
        local yellow = lsyUVColorFloats 255 230 40
        require (yellow.x == 1 and yellow.y < 1 and yellow.z < yellow.y) "RGB must be normalized without saturating white."
        count += 1
        require (lsyUVIsBaseSlot "Base/Albedo") "PBR Base/Albedo slot must be recognized."
        require (not (lsyUVIsBaseSlot "Normal Map")) "Normal map must not be treated as Base Color."
        count += 1
        local points = #([0,0,5],[2,0,-8])
        local turned = lsyUVCalculate points #rotate 90
        require ((length (turned[1] - [1,-1,5])) < 0.00001) "90 degree UV rotation is wrong."
        require ((length (turned[2] - [1,1,-8])) < 0.00001) "Rotation must preserve W."
        local aligned = lsyUVCalculate points #align_u_center 0
        require (aligned[1] == [1,0,5] and aligned[2] == [1,0,-8]) "U alignment must preserve V/W."
        count += 1
        resolved = lsyUVResolveID multi 4
        require (resolved[1] == undefined) "Missing material ID must not choose another slot."
        count += 1
        multi.mapEnabled[2] = false
        resolved = lsyUVResolveID multi 7
        require (resolved[1] == undefined) "Disabled submaterial must not resolve an image."
        count += 1
        multi.mapEnabled[2] = true
        multi.materialIDList = #(2,2,42)
        resolved = lsyUVResolveID multi 2
        require (resolved[1] == undefined) "Duplicate IDs must not choose an arbitrary slot."
        count += 1
        ma.diffuseMapEnable = false
        resolved = lsyUVResolveID ma 1
        require (resolved[1] == undefined) "Disabled Diffuse must not resolve an image."
        count += 1

        -- Reproduce the observed 8 texture entries / 9 dropdown entries.
        lsyUVMod = LSYUVListFixture texMapList:#(ma,mb,mc,a,b,c,ma,mb)
        require ((lsyUVDropdownIndex 5) == 6) "Texture index 5 must map to dropdown 6."
        require ((lsyUVMapAtDropdown 6) == b) "Dropdown 6 must read texture entry 5."
        require ((lsyUVMapAtDropdown 1) == undefined) "Leading special entry is not a texture."
        count += 1
        lsyUVMod = LSYUVListFixture texMapList:#(a)
        require ((lsyUVMapIndex a register:true) == 2) "Existing map must be reused."
        require (lsyUVMod.texMapList.count == 1) "Reusing a map must not append an entry."
        require ((lsyUVMapIndex b register:true) == 3) "New map index must include dropdown offset."
        count += 1
        lsyUVMod = previousMod
        format "LSY Workbench host helper tests: % PASS\n" count
    )
    catch
    (
        lsyUVMod = previousMod
        throw()
    )
)
