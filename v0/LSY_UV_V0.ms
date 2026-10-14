/*
LSY UV Repair - V0 native-editor probe
Run with Scripting > Run Script in 3ds Max 2023 or 2025.
The panel never writes UV coordinates or changes geometry/materials.
Visual settings and native transform modes only affect the chosen Unwrap UVW.
*/

global LSYV0_Rollout
global LSYV0_State
global LSYV0_Batch
global lsyv0

-- A previous run may have modified display settings. Restore them before reloading.
try
(
    if lsyv0 != undefined do
    (
        if lsyv0.baseline != undefined do
        (
            local oldMod = lsyv0.mod
            oldMod.setTickSize lsyv0.baseline[1]
            oldMod.setHitSize lsyv0.baseline[2]
            oldMod.setSelectionColor lsyv0.baseline[3]
            oldMod.setLineColor lsyv0.baseline[4]
        )
    )
) catch ()

struct LSYV0_State
(
    node = undefined,
    mod = undefined,
    baseline = undefined,
    before = undefined,
    dragged = undefined,
    lines = #(),
    stepResults = #()
)

lsyv0 = LSYV0_State()

fn lsyv0Log message =
(
    local line = message as string
    append lsyv0.lines line
    format "LSY V0: %\n" line
    line
)

fn lsyv0Target =
(
    if selection.count != 1 then
    (
        lsyv0Log "Select exactly one object."
        return false
    )
    local n = selection[1]
    local m = undefined
    try
    (
        local current = modPanel.getCurrentObject()
        if classOf current == Unwrap_UVW do m = current
    ) catch ()
    if m != undefined do
    (
        local belongs = false
        for candidate in n.modifiers where candidate == m do belongs = true
        if not belongs do m = undefined
    )
    if m == undefined then
    (
        for candidate in n.modifiers where classOf candidate == Unwrap_UVW do
        (
            m = candidate
            exit
        )
    )
    if m == undefined then
    (
        lsyv0Log "Selected object has no Unwrap UVW modifier. Add one manually to a saved test scene."
        return false
    )
    if lsyv0.node != n or lsyv0.mod != m then
    (
        if lsyv0.baseline != undefined then
        (
            lsyv0Log "Restore the previous target's visual settings before switching objects."
            return false
        )
        lsyv0.node = n
        lsyv0.mod = m
        lsyv0.before = undefined
        lsyv0.dragged = undefined
        lsyv0.baseline = undefined
        lsyv0Log ("Target: " + n.name + " / " + m.name)
    )
    true
)

fn lsyv0Channel m =
(
    local raw = m.getMapChannel()
    local result = ""
    if m.getVC() then result = "Vertex Color"
    else if raw == 0 then result = "UV 1 (raw API value 0)"
    else result = "UV " + (raw as string)
    result
)

fn lsyv0Diagnostic =
(
    lsyv0Log ("maxVersion: " + (maxVersion() as string))
    lsyv0Log ("scene: " + maxFileName)
    if not lsyv0Target() then return false
    local m = lsyv0.mod
    local n = lsyv0.node
    lsyv0Log ("node class: " + (classOf n.baseObject as string))
    lsyv0Log ("modifier count: " + (n.modifiers.count as string))
    try (lsyv0Log ("channel: " + lsyv0Channel m)) catch (lsyv0Log "channel: API error")
    try (lsyv0Log ("UV vertices: " + (m.numberVerticesByNode n as string))) catch (lsyv0Log "UV vertices: API error")
    try (lsyv0Log ("UV faces: " + (m.numberPolygonsByNode n as string))) catch (lsyv0Log "UV faces: API error")
    try (lsyv0Log ("selection mode (0/1/2/3): " + (m.getTVSubObjectMode() as string))) catch (lsyv0Log "selection mode: API error")
    try (lsyv0Log ("selected UV vertices: " + ((m.getSelectedVertices() as array).count as string))) catch (lsyv0Log "selected UV vertices: API error")
    try (lsyv0Log ("selected UV faces: " + ((m.getSelectedFaces() as array).count as string))) catch (lsyv0Log "selected UV faces: API error")
    try (lsyv0Log ("freeform: " + (m.getFreeFormMode() as string))) catch (lsyv0Log "freeform: API error")
    try (lsyv0Log ("selection lock: " + (m.getLock() as string))) catch (lsyv0Log "selection lock: API error")
    try (lsyv0Log ("soft selection: " + (m.getEnableSoftSelection() as string))) catch (lsyv0Log "soft selection: API error")
    try (lsyv0Log ("selected tick size: " + (m.getTickSize() as string))) catch (lsyv0Log "selected tick size: API error")
    try (lsyv0Log ("click hit size: " + (m.getHitSize() as string))) catch (lsyv0Log "click hit size: API error")
    lsyv0Log "P0 diagnostic captured. Runtime Python/Qt details: run v0_runtime_probe.py separately."
    true
)

fn lsyv0ApplyVisibility tick hit selectedColor edgeColor =
(
    if not lsyv0Target() then return false
    local m = lsyv0.mod
    if lsyv0.baseline == undefined then
    (
        try
        (
            lsyv0.baseline = #(m.getTickSize(), m.getHitSize(), m.getSelectionColor(), m.getLineColor())
        )
        catch
        (
            lsyv0Log "Cannot read original visual settings. Nothing changed."
            return false
        )
    )
    try
    (
        m.setTickSize tick
        m.setHitSize hit
        m.setSelectionColor (point3 (selectedColor.r / 255.0) (selectedColor.g / 255.0) (selectedColor.b / 255.0))
        m.setLineColor (point3 (edgeColor.r / 255.0) (edgeColor.g / 255.0) (edgeColor.b / 255.0))
        m.UpdateView()
        lsyv0Log ("P1 visual settings applied: selected tick=" + tick as string + ", hit=" + hit as string)
        true
    )
    catch
    (
        lsyv0Log "P1 visual setting failed. Use Restore settings."
        false
    )
)

fn lsyv0RestoreVisibility =
(
    if lsyv0.baseline == undefined then
    (
        lsyv0Log "No saved visual settings."
        return false
    )
    local m = lsyv0.mod
    if m == undefined then return false
    try
    (
        m.setTickSize lsyv0.baseline[1]
        m.setHitSize lsyv0.baseline[2]
        m.setSelectionColor lsyv0.baseline[3]
        m.setLineColor lsyv0.baseline[4]
        m.UpdateView()
        lsyv0.baseline = undefined
        lsyv0Log "Original visual settings restored."
        true
    )
    catch
    (
        lsyv0Log "Could not restore visual settings. Reopen the target modifier and restore manually."
        false
    )
)

fn lsyv0Mode mode =
(
    if not lsyv0Target() then return false
    local m = lsyv0.mod
    try
    (
        case mode of
        (
            #move: m.move()
            #moveU: m.moveH()
            #moveV: m.moveV()
            #rotate: m.rotate()
            #scale: m.scale()
            #scaleU: m.scaleH()
            #scaleV: m.scaleV()
            #freeform: m.setFreeFormMode true
            #pivot: m.snapPivot 1
        )
        lsyv0Log ("P1 native mode: " + mode as string)
        if lsyv0.before != undefined do
        (
            lsyv0.before = undefined
            lsyv0.dragged = undefined
            lsyv0Log "P2 snapshot cleared after mode change. Capture selected UVs before the next drag."
        )
        true
    )
    catch
    (
        lsyv0Log ("P1 mode failed: " + mode as string + ". Make the Unwrap modifier active in Modify panel and open UV Editor manually.")
        false
    )
)

fn lsyv0CaptureSelected =
(
    if not lsyv0Target() then return false
    local m = lsyv0.mod
    local ids = #()
    local positions = #()
    try
    (
        ids = m.getSelectedVertices() as array
        if ids.count == 0 then
        (
            lsyv0Log "Select UV vertices in the native editor first."
            return false
        )
        for id in ids do append positions (m.getVertexPosition currentTime id)
        lsyv0.before = #(lsyv0.node, lsyv0.mod, lsyv0Channel m, ids, positions, currentTime)
        lsyv0.dragged = undefined
        lsyv0Log ("P2 snapshot: " + ids.count as string + " UV vertices; channel=" + lsyv0.before[3])
        true
    )
    catch
    (
        lsyv0.before = undefined
        lsyv0.dragged = undefined
        lsyv0Log "P2 snapshot failed. Check modifier/UI context."
        false
    )
)

fn lsyv0CompareSelected phase =
(
    if lsyv0.before == undefined then
    (
        lsyv0Log "P2: Capture selected UV vertices first."
        return false
    )
    if not lsyv0Target() then return false
    local b = lsyv0.before
    if b[1] != lsyv0.node or b[2] != lsyv0.mod then
    (
        lsyv0Log "P2 target changed. Snapshot invalid."
        return false
    )
    local m = lsyv0.mod
    local currentChannel = lsyv0Channel m
    if currentChannel != b[3] then
    (
        lsyv0Log "P2 channel changed. Snapshot invalid."
        return false
    )
    if currentTime != b[6] then
    (
        lsyv0Log "P2 time changed. Snapshot invalid."
        return false
    )
    if (phase == #undo or phase == #redo) and lsyv0.dragged == undefined then
    (
        lsyv0Log "P2: Compare after drag before checking Undo or Redo."
        return false
    )
    if phase == #drag and lsyv0.dragged != undefined then
    (
        lsyv0Log "P2: This drag was already captured. Capture selected UVs for a new cycle."
        return false
    )
    local positions = #()
    local maxFromInitial = 0.0
    local maxFromExpected = 0.0
    local changedFromInitial = 0
    try
    (
        for i = 1 to b[4].count do
        (
            local p = m.getVertexPosition currentTime b[4][i]
            append positions p
            local d = distance p b[5][i]
            if d > maxFromInitial do maxFromInitial = d
            if d > 0.000001 do changedFromInitial += 1
            if phase == #redo do
            (
                local expectedDelta = distance p (lsyv0.dragged[i])
                if expectedDelta > maxFromExpected do maxFromExpected = expectedDelta
            )
        )
        local selectedNow = m.getSelectedVertices() as array
        if phase == #drag then
        (
            if changedFromInitial > 0 do lsyv0.dragged = positions
            lsyv0Log ("P2 after drag: captured=" + b[4].count as string + ", currently selected=" + selectedNow.count as string + ", changed=" + changedFromInitial as string + ", max from initial=" + maxFromInitial as string)
            if changedFromInitial > 0 and changedFromInitial < b[4].count do lsyv0Log "P2 CHECK: Only some captured UVs moved. Inspect whether clicking the handle changed selection."
        )
        else if phase == #undo then
        (
            lsyv0Log ("P2 after Undo: max from initial=" + maxFromInitial as string + (if maxFromInitial <= 0.000001 then " PASS" else " FAIL"))
        )
        else if phase == #redo then
        (
            lsyv0Log ("P2 after Redo: max from drag=" + maxFromExpected as string + ", max from initial=" + maxFromInitial as string + (if maxFromExpected <= 0.000001 then " PASS" else " FAIL"))
            lsyv0.before = undefined
            lsyv0.dragged = undefined
            lsyv0Log "P2 cycle complete. Capture selected UVs before testing another drag."
        )
        true
    )
    catch
    (
        lsyv0Log "P2 comparison failed. Topology or evaluated modifier may have changed."
        false
    )
)

fn lsyv0MaterialProbe =
(
    if not lsyv0Target() then return false
    local n = lsyv0.node
    local m = lsyv0.mod
    if classOf n.baseObject != Editable_Poly or n.modifiers.count != 1 then
    (
        lsyv0Log "P3 read-only check supports Editable Poly with one Unwrap modifier only. Face index correspondence is unverified for this stack."
        return false
    )
    local ids = #()
    try (ids = m.getSelectedFaces() as array) catch
    (
        lsyv0Log "P3 cannot read selected UV faces."
        return false
    )
    if ids.count == 0 then
    (
        lsyv0Log "P3: Select UV faces in the editor first."
        return false
    )
    local material = n.material
    local logCount = ids.count
    if logCount > 100 then
    (
        logCount = 100
        lsyv0Log "P3 logging first 100 selected faces only."
    )
    for faceOffset = 1 to logCount do
    (
        local faceIndex = ids[faceOffset]
        local faceID = undefined
        try (faceID = polyop.getFaceMatID n.baseObject faceIndex) catch ()
        if faceID == undefined then
            lsyv0Log ("P3 face " + faceIndex as string + ": material ID read failed")
        else
        (
            local submat = material
            local slot = 0
            if material != undefined and isProperty material #materialIDList do
            (
                slot = findItem material.materialIDList faceID
                submat = if slot > 0 then material.materialList[slot] else undefined
            )
            local map = undefined
            if submat != undefined do
            (
                if isProperty submat #base_color_map and isProperty submat #base_color_map_on then
                (
                    if submat.base_color_map_on do map = submat.base_color_map
                )
                else if isProperty submat #diffuseMap and isProperty submat #diffuseMapEnable do
                (
                    if submat.diffuseMapEnable do map = submat.diffuseMap
                )
            )
            local path = "<none or nested/unsupported>"
            if map != undefined and isProperty map #filename do path = map.filename as string
            lsyv0Log ("P3 face=" + faceIndex as string + " ID=" + faceID as string + " slot=" + slot as string + " map=" + path)
        )
    )
    true
)

fn lsyv0Record step status note =
(
    local line = step + " | " + status + " | " + note
    append lsyv0.stepResults line
    lsyv0Log ("RESULT " + line)
)

fn lsyv0SaveReport =
(
    local path = getSaveFileName caption:"Save LSY V0 report" types:"Text report (*.txt)|*.txt|"
    if path == undefined then return false
    local stream = undefined
    try
    (
        stream = createFile path
        format "LSY UV Repair V0 report\n" to:stream
        format "Max version: %\nScene: %\n" (maxVersion() as string) maxFileName to:stream
        format "Target: %\n\n" (if lsyv0.node == undefined then "none" else lsyv0.node.name) to:stream
        for line in lsyv0.lines do format "%\n" line to:stream
        close stream
        lsyv0Log ("Report saved: " + path)
        true
    )
    catch
    (
        if stream != undefined do try (close stream) catch ()
        lsyv0Log "Report save failed. Check destination permissions."
        false
    )
)

try (destroyDialog LSYV0_Rollout) catch ()

rollout LSYV0_Rollout "LSY UV Repair | V0 Probe" width:316
(
    label intro "Native Unwrap probe; use a saved COPY of your scene." align:#left
    button diagnostic "P0  Diagnose selected object" width:296
    label editorHelp "Open UV Editor manually on active Unwrap UVW." align:#left

    group "P1  Visibility" (
        spinner tick "Selected point px" range:[1,32,6] type:#integer fieldwidth:50
        spinner hit "Click hit px" range:[1,32,6] type:#integer fieldwidth:50
        colorpicker selectedColor "Selected color" color:(color 255 230 50)
        colorpicker edgeColor "Edge color" color:(color 60 200 255)
        button applyVisual "Apply visual settings" width:144 across:2
        button restoreVisual "Restore original settings" width:144
    )
    group "P1  Native gizmo" (
        button freeform "Freeform ON" width:144 across:2
        button pivot "Pivot center" width:144
        button move "Move" width:95 across:3
        button rotate "Rotate" width:95
        button scale "Scale" width:95
        button moveU "Move U" width:95 across:3
        button moveV "Move V" width:95
        button scaleU "Scale U" width:95
        button scaleV "Scale V" width:95
    )
    group "P2  Manual drag / Undo / Redo" (
        button before "Capture selected UVs" width:296
        button after "Compare after drag" width:144 across:2
        button afterUndo "Compare after Undo" width:144
        button afterRedo "Compare after Redo" width:296
    )
    group "P3  Material ID (read only)" (
        button materialProbe "Inspect selected UV faces" width:296
    )
    group "Result" (
        dropdownlist step "Step" items:#("P0 environment", "P1 visibility", "P1 gizmo", "P2 drag/Undo", "P3 material ID") selection:1 width:290
        edittext note "Note" text:"" width:290
        button pass "Record PASS" width:95 across:3
        button fail "Record FAIL" width:95
        button skip "Record SKIP" width:95
        button save "Save report" width:296
    )

    on diagnostic pressed do lsyv0Diagnostic()
    on applyVisual pressed do lsyv0ApplyVisibility tick.value hit.value selectedColor.color edgeColor.color
    on restoreVisual pressed do lsyv0RestoreVisibility()
    on freeform pressed do lsyv0Mode #freeform
    on pivot pressed do lsyv0Mode #pivot
    on move pressed do lsyv0Mode #move
    on rotate pressed do lsyv0Mode #rotate
    on scale pressed do lsyv0Mode #scale
    on moveU pressed do lsyv0Mode #moveU
    on moveV pressed do lsyv0Mode #moveV
    on scaleU pressed do lsyv0Mode #scaleU
    on scaleV pressed do lsyv0Mode #scaleV
    on before pressed do lsyv0CaptureSelected()
    on after pressed do lsyv0CompareSelected #drag
    on afterUndo pressed do lsyv0CompareSelected #undo
    on afterRedo pressed do lsyv0CompareSelected #redo
    on materialProbe pressed do lsyv0MaterialProbe()
    on pass pressed do lsyv0Record step.selected "PASS" note.text
    on fail pressed do lsyv0Record step.selected "FAIL" note.text
    on skip pressed do lsyv0Record step.selected "SKIP" note.text
    on save pressed do lsyv0SaveReport()
)

if LSYV0_Batch != true do createDialog LSYV0_Rollout
