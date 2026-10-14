/* Native UV workbench. Point tools write selected UV coordinates with Undo.
   Geometry, materials and face IDs are never written. Host validation required. */
global LSYUVWorkbench
global LSYUVTools
global LSYUVDisplay
global LSYUVEditOps
global LSYUVTileOps
global LSYUVNativeOps
global LSYUVAdvanced
global LSYUVSimilar
global LSYUVStack
global LSYUVTexel
global lsyUVStackPlan
global lsyUVDensityPlan
global lsyUVRepairPlan
global lsyUVDensityData
global lsyUVSimilarMatches
global lsyUVTopologyEqual
global lsyUVCommitCoordinates
global lsyUVRunDensityMath
global lsyUVFilterUISync
global lsyUVIsolation
global lsyUVFilterBridge
global lsyUVFilterBridgeVersion
global lsyUVGetFilterBridge
global lsyUVQtIDs
global lsyUVQtTarget
global lsyUVQtMapping
global lsyUVQtError
global lsyUVFilterState
global lsyUVNativeAutoState
global lsyUVNativeOperation
global lsyUVNativeIDs
global lsyUVNativeNames
global lsyUVNativeTarget
global lsyUVNativeResult
global lsyUVNativeError
global lsyUVNativeUI
global lsyUVLinkedDisplayState
global lsyUVBackgroundRefreshBusy = false
global lsyUVReferenceSnapshot
global lsyUVReferenceIsland
global lsyUVSimilarSnapshot
global lsyUVSimilarFaces
global lsyUVInvalidateAnalysis
global lsyUVEditorReady
global lsyUVFaceAutoPending = false
global lsyUVBackgroundStage = "idle"
global lsyUVHasAnimatedPoints
global lsyUVCheckWriteContext
global lsyUVIsolationRestore
global lsyUVNode
global lsyUVMod
global lsyUVOriginal
global lsyUVApplied
global lsyUVRestore
global lsyUVBackground
global lsyUVBackgroundOriginal
global lsyUVBackgroundApplied
global lsyUVBackgroundRestore
global lsyUVBackgroundRefresh
global lsyUVBackgroundKey
global lsyUVImageCache
global lsyUVSelectionInfo
global lsyUVBackgroundIndexVersion
global lsyUVBackgroundSummary
global lsyUVLastStatus
global lsyUVUISyncing
global lsyUVSyncDisplay
global lsyUVEditBlockedNode
global lsyUVSlotMaps
global lsyUVSlotOwner
global lsyUVSlotIndices
global lsyUVPendingBackgroundRestores
global lsyUVRestoreBackgroundState

-- BEGIN NATIVE UI SESSION
fn lsyUVNativeUI operation target:0 =
(
    lsyUVNativeOperation=operation
    lsyUVNativeTarget=target
    lsyUVNativeIDs=#()
    if operation!="maps" do for f=1 to (polyop.getNumFaces lsyUVNode.baseObject) do appendIfUnique lsyUVNativeIDs (polyop.getFaceMatID lsyUVNode.baseObject f)
    lsyUVNativeNames=for map in lsyUVMod.texMapList collect (if map==undefined then "" else map.name)
    lsyUVNativeResult=undefined
    lsyUVNativeError=""
    python.Execute "\"\"\"Native UV display menus; no geometry or face/vertex selection writes.\"\"\"\nimport re\n\n\ndef id_value(label):\n    m = re.match(r'^\\s*(?:(?:material|mat)?\\s*id\\s*[:#]?\\s*)?(\\d+)(?:\\s*$|\\s*[:(\\[\\-])', label, re.I)\n    return int(m.group(1)) if m else None\n\n\ndef id_slots(labels, expected):\n    slots = {}\n    special = []\n    for i, label in enumerate(labels):\n        value = id_value(label)\n        if value is None:\n            if re.search(r'\\d|[./\\\\]', label):\n                return None\n            special.append(i)\n        elif value in slots:\n            return None\n        else:\n            slots[value] = i\n    if len(special) == 1 and 0 not in slots:\n        slots[0] = special[0]\n    if 0 not in slots or not set(expected).issubset(slots):\n        return None\n    return slots\n\n\nclass MenuItems:\n    def __init__(self, menu):\n        self.menu = menu\n        self.actions = [a for a in menu.actions() if not a.isSeparator()]\n    def labels(self): return [a.text().replace('&', '') for a in self.actions]\n    def current(self):\n        checked = [i for i,a in enumerate(self.actions) if a.isChecked()]\n        return checked[0] if len(checked) == 1 else -1\n    def choose(self, i):\n        if not self.actions[i].isEnabled(): raise RuntimeError('Native menu item disabled')\n        self.actions[i].trigger()\n        if not self.actions[i].isChecked():\n            raise RuntimeError('Native menu did not confirm selected item')\n\n\nclass ComboItems:\n    def __init__(self, combo):self.combo=combo\n    def labels(self):return [self.combo.itemText(i) for i in range(self.combo.count())]\n    def current(self):return self.combo.currentIndex()\n    def choose(self,i):\n        self.combo.setCurrentIndex(i)\n        if self.combo.currentIndex()!=i:raise RuntimeError('Native combo selection mismatch')\n\n\ndef qt_items():\n    try:from PySide2 import QtWidgets\n    except ImportError:from PySide6 import QtWidgets\n    items=[]\n    for w in QtWidgets.QApplication.allWidgets():\n        if isinstance(w, QtWidgets.QComboBox) and w.isVisible():items.append(ComboItems(w))\n        elif isinstance(w, QtWidgets.QMenu):\n            # Menus can remain hidden while the native selector is visible.\n            if w.actions():items.append(MenuItems(w))\n    return items\n\n\ndef find_id(items, expected):\n    matches=[]\n    for item in items:\n        slots=id_slots(item.labels(),expected)\n        if slots is not None and item.current()>=0:matches.append((item,slots))\n    exact=[m for m in matches if set(m[1])==set(expected)|{0}]\n    matches=exact or matches\n    if len(matches)!=1:\n        combos=sum(isinstance(i,ComboItems) for i in items)\n        checked=sum(isinstance(i,MenuItems) and i.current()>=0 for i in items)\n        raise RuntimeError('Native ID UI matches=%d; expected=%s; combos=%d checked-menus=%d' % (len(matches),sorted(expected)[:24],combos,checked))\n    return matches[0]\n\n\ndef find_maps(items, names, native_current):\n    matches=[]\n    for item in items:\n        selected=item.current()\n        if selected<0:continue\n        offset=native_current-selected\n        if offset not in (0,1):continue\n        mapping=[0]*len(names)\n        valid=True\n        for index,label in enumerate(item.labels()):\n            candidates=[i for i,name in enumerate(names) if name and\n                        (label.lower()==name.lower() or\n                         (label.lower().startswith(name.lower()) and len(label)>len(name) and not label[len(name)].isalnum()))]\n            if len(candidates)>1:valid=False;break\n            if candidates:\n                target=candidates[0]\n                if mapping[target] or index+offset<1:valid=False;break\n                mapping[target]=index+offset\n        if valid and any(mapping):matches.append(mapping)\n    if len(matches)!=1:raise RuntimeError('Native texture UI matches=%d; background preserved' % len(matches))\n    return matches[0]\n\n\ndef run_host():\n    from pymxs import runtime as rt\n    rt.lsyUVNativeResult=rt.undefined\n    rt.lsyUVNativeError=''\n    try:\n        items=qt_items()\n        if str(rt.lsyUVNativeOperation)=='maps':\n            result=find_maps(items,[str(n) for n in rt.lsyUVNativeNames],int(rt.lsyUVMod.getCurrentMap()))\n        else:\n            item,slots=find_id(items,[int(i) for i in rt.lsyUVNativeIDs])\n            target=int(rt.lsyUVNativeTarget)\n            before=item.current()\n            old_id=next(k for k,v in slots.items() if v==before)\n            if target not in slots:raise RuntimeError('Requested ID absent from native UI')\n            if str(rt.lsyUVNativeOperation)=='select_id':\n                try:\n                    rt.lsyUVMod.setMatID(slots[target]+1)\n                    if int(rt.lsyUVMod.getMatID())!=slots[target]+1 or item.current()!=slots[target]:\n                        raise RuntimeError('Native ID index/UI selection mismatch')\n                except Exception:\n                    rt.lsyUVMod.setMatID(before+1)\n                    raise\n            result=[old_id,int(rt.lsyUVMod.getMatID()),target]\n        rt.lsyUVNativeResult=rt.Array(*result)\n    except Exception as exc:\n        rt.lsyUVNativeError=str(exc)\n        try:\n            rt.lsyUVNativeError += '; filter=%d auto=%s maps=%d texture-list=%d current-map=%d' % (\n                int(rt.lsyUVMod.getMatID()), bool(rt.lsyUVMod.getAutoBackground()),\n                int(rt.lsyUVMod.numberMaps()), len(rt.lsyUVNativeNames),\n                int(rt.lsyUVMod.getCurrentMap()))\n        except Exception:\n            pass\n\nrun_host()\n"
    if lsyUVNativeResult==undefined then throw lsyUVNativeError
    lsyUVNativeResult
)
-- END NATIVE UI SESSION

-- Restore each owned property independently. Map identity equality needs no index lookup.
fn lsyUVRestoreBackgroundState modifier original applied =
(
    local issues = #()
    if original == undefined or applied == undefined then return issues
    if original[1] != applied[1] do
    (
        try
        (
            local maps = modifier.texMapList
            local count = modifier.numberMaps()
            if count != maps.count + 1 then
                append issues "Map list layout changed; current map preserved."
            else
            (
                local index = modifier.getCurrentMap()
                local current = if index > 1 and index <= count then maps[index-1] else undefined
                if current == applied[1] do
                (
                    local target = if original[1] == undefined and original[2] == 1 then 1 else 0
                    if original[1] != undefined do
                    (
                        local old = findItem maps original[1]
                        if old > 0 do target = old+1
                    )
                    if target > 0 then
                    (
                        modifier.SetCurrentMap target
                        if modifier.getCurrentMap() != target do append issues "Map restore readback mismatch."
                    )
                    else append issues "Original map is no longer registered; current map preserved."
                )
            )
        )
        catch (append issues ("Map restore: " + getCurrentException()))
    )
    try
    (
        if applied[2] != undefined and modifier.getShowMap() == applied[2] do
        (
            modifier.setShowMap original[3]
            if modifier.getShowMap() != original[3] do append issues "Show-map restore readback mismatch."
        )
    )
    catch (append issues ("Show-map restore: " + getCurrentException()))
    try
    (
        if applied[3] != undefined and modifier.getAutoBackground() == applied[3] do
        (
            modifier.setAutoBackground original[4]
            if modifier.getAutoBackground() != original[4] do append issues "Auto-background restore readback mismatch."
        )
    )
    catch (append issues ("Auto-background restore: " + getCurrentException()))
    try (modifier.updateMap()) catch (append issues ("Map refresh: " + getCurrentException()))
    issues
)

-- Close the previous instance before replacing its functions/state.
try (LSYUVWorkbench.backgroundTimer.active=false) catch ()
if lsyUVMod!=undefined do
(
    local nativeReady=false
    try (nativeReady=lsyUVMod.numberMaps()>0) catch ()
    if not nativeReady do
    (
        if lsyUVPendingBackgroundRestores==undefined do lsyUVPendingBackgroundRestores=#()
        append lsyUVPendingBackgroundRestores #(lsyUVMod,lsyUVBackgroundOriginal,lsyUVBackgroundApplied,#("Editor unavailable during upgrade"))
        lsyUVBackgroundOriginal=undefined
        lsyUVBackgroundApplied=undefined
        lsyUVFilterState=undefined
        lsyUVNativeAutoState=undefined
    )
)
if (lsyUVIsolation != undefined or lsyUVFilterState != undefined or lsyUVNativeAutoState != undefined) and lsyUVIsolationRestore != undefined do
    if not lsyUVIsolationRestore() then throw "Restore UV isolation before reloading."
if lsyUVOriginal != undefined do
(
    if lsyUVRestore == undefined then throw "Previous display state cannot be restored. Restore it before reloading."
    if not lsyUVRestore() then throw "Display restore failed. Retry Restore before reloading."
)
if lsyUVBackgroundOriginal != undefined do
(
    if lsyUVBackgroundIndexVersion != 1 then
    (
        -- Migrate the previous build's saved raw dropdown index. Its old restore
        -- function used the incorrect texture-list index, so do not call it.
        local savedIndex = if classOf lsyUVBackgroundOriginal[1] == Integer then
            lsyUVBackgroundOriginal[1] else lsyUVBackgroundOriginal[2]
        if lsyUVBackgroundApplied != undefined do
        (
            local appliedIndex = if classOf lsyUVBackgroundApplied[1] == Integer then
                lsyUVBackgroundApplied[1] else findItem lsyUVMod.texMapList lsyUVBackgroundApplied[1]
            if appliedIndex > 0 and lsyUVMod.getCurrentMap() == appliedIndex do
                if savedIndex >= 1 and savedIndex <= lsyUVMod.numberMaps() do lsyUVMod.SetCurrentMap savedIndex
            if lsyUVBackgroundApplied[2] != undefined and lsyUVMod.getShowMap() == lsyUVBackgroundApplied[2] do
                lsyUVMod.setShowMap lsyUVBackgroundOriginal[3]
            if lsyUVBackgroundApplied[3] != undefined and lsyUVMod.getAutoBackground() == lsyUVBackgroundApplied[3] do
                lsyUVMod.setAutoBackground lsyUVBackgroundOriginal[4]
        )
        lsyUVBackgroundOriginal = undefined
        lsyUVBackgroundApplied = undefined
        lsyUVMod.updateMap()
    )
    else
    (
        local issues = lsyUVRestoreBackgroundState lsyUVMod lsyUVBackgroundOriginal lsyUVBackgroundApplied
        if issues.count > 0 do
        (
            if lsyUVPendingBackgroundRestores == undefined do lsyUVPendingBackgroundRestores = #()
            append lsyUVPendingBackgroundRestores #(lsyUVMod,lsyUVBackgroundOriginal,lsyUVBackgroundApplied,issues)
            for issue in issues do format "LSY UV reload: %\n" issue
            format "LSY UV reload: Unresolved restore state retained; loading continues.\n"
        )
        lsyUVBackgroundOriginal = undefined
        lsyUVBackgroundApplied = undefined
    )
)
try (destroyDialog LSYUVWorkbench) catch ()
-- Release a pending plan from pre-0.15.1 builds; new tools own separate plans.
lsyUVRepairPlan=undefined
lsyUVNode = undefined
lsyUVMod = undefined
lsyUVOriginal = undefined
lsyUVApplied = undefined
lsyUVBackground = undefined
lsyUVBackgroundOriginal = undefined
lsyUVBackgroundApplied = undefined
lsyUVBackgroundKey = undefined
if lsyUVImageCache == undefined do lsyUVImageCache = #()
lsyUVSelectionInfo = ""
lsyUVBackgroundIndexVersion = 1
lsyUVBackgroundSummary = ""
lsyUVLastStatus = undefined
lsyUVUISyncing = true
lsyUVSlotMaps = #()
lsyUVSlotOwner = undefined
lsyUVSlotIndices = #()

fn lsyUVStatus text =
(
    try (LSYUVWorkbench.status.text = text) catch ()
    if text != lsyUVLastStatus do
    (
        format "LSY UV Workbench 0.15.1: %\n" text
    )
    lsyUVLastStatus = text
)

fn lsyUVBackgroundMessage text =
(
    LSYUVTools.backgroundInfo.text = text + (if lsyUVBackgroundSummary == "" then "" else "\n" + lsyUVBackgroundSummary)
)

fn lsyUVValid =
(
    if lsyUVNode == undefined or lsyUVMod == undefined then
    (
        lsyUVStatus "오브젝트의 Unwrap을 선택하고 대상 연결을 먼저 누르세요."
        return false
    )
    if not isValidNode lsyUVNode then
    (
        lsyUVStatus "연결된 오브젝트가 삭제됐습니다. 새 대상을 연결하세요."
        return false
    )
    local belongs = false
    for m in lsyUVNode.modifiers where m == lsyUVMod do belongs = true
    if not belongs then
    (
        lsyUVStatus "연결된 Unwrap이 제거됐습니다. 새 대상을 연결하세요."
        return false
    )
    if selection.count != 1 then
    (
        lsyUVStatus "연결된 오브젝트를 먼저 선택하세요."
        return false
    )
    if selection[1] != lsyUVNode or modPanel.getCurrentObject() != lsyUVMod then
    (
        lsyUVStatus "Modify 패널에서 연결된 Unwrap을 활성화하세요."
        return false
    )
    true
)

fn lsyUVGetVisual index =
(
    case index of
    (
        1: lsyUVMod.getTickSize()
        2: lsyUVMod.getHitSize()
        3: lsyUVMod.getSelectionColor()
        4: lsyUVMod.getLineColor()
        5: lsyUVMod.getOpenEdgeColor()
        6: lsyUVMod.getFreeFormColor()
        7: lsyUVMod.getSharedColor()
        8: lsyUVMod.getDisplayOpenEdges()
        9: lsyUVMod.getShowShared()
    )
)

fn lsyUVSetVisual index value =
(
    case index of
    (
        1: lsyUVMod.setTickSize value
        2: lsyUVMod.setHitSize value
        3: lsyUVMod.setSelectionColor value
        4: lsyUVMod.setLineColor value
        5: lsyUVMod.setOpenEdgeColor value
        6: lsyUVMod.setFreeFormColor value
        7: lsyUVMod.setSharedColor value
        8: lsyUVMod.setDisplayOpenEdges value
        9: lsyUVMod.setShowShared value
    )
)

fn lsyUVVisualEqual index first second =
(
    if index >= 3 and index <= 7 then (length (first - second)) < 0.000001
    else first == second
)

fn lsyUVRestore =
(
    if lsyUVOriginal == undefined then return true
    local allOK = true
    for i = 1 to lsyUVOriginal.count where lsyUVApplied[i] != undefined do
    (
        try
        (
            local current = lsyUVGetVisual i
            if lsyUVVisualEqual i current lsyUVApplied[i] do lsyUVSetVisual i lsyUVOriginal[i]
            lsyUVApplied[i] = undefined
        )
        catch (allOK = false)
    )
    if allOK then
    (
        lsyUVOriginal = undefined
        lsyUVApplied = undefined
        try (lsyUVMod.UpdateView()) catch ()
        lsyUVStatus "표시 복원 완료. 외부에서 바꾼 값은 유지했습니다."
    )
    else lsyUVStatus "표시 복원이 완료되지 않았습니다. 대상 변경 전에 재시도하세요."
    allOK
)

-- Clear derived analysis on session changes and before a fresh search.
fn lsyUVInvalidateAnalysis clearReference:false invalidateCoordinates:false =
(
    lsyUVSimilarSnapshot=undefined
    lsyUVSimilarFaces=#{}
    lsyUVSimilarMatches=#()
    lsyUVStackPlan=undefined
    try (LSYUVStack.applyPlan.enabled=false; LSYUVStack.rows.items=#(); LSYUVStack.info.text="유사 섬 검색 후 Stack을 계산하세요.") catch ()
    if invalidateCoordinates do
    (
        lsyUVDensityPlan=undefined
        lsyUVDensityData=undefined
        try (LSYUVTexel.applyPlan.enabled=false; LSYUVTexel.rows.items=#(); LSYUVTexel.info.text="밀도를 조회하거나 변경을 계산하세요.") catch ()
    )
    if clearReference do
    (
        lsyUVReferenceSnapshot=undefined
        lsyUVReferenceIsland=undefined
    )
    try
    (
        LSYUVSimilar.results.items=#()
        LSYUVSimilar.info.text=if clearReference then "기준 섬을 먼저 지정하세요." else "검색 결과를 다시 계산하세요."
    ) catch ()
    true
)

-- A synchronous coordinate command must not join another Hold or create keys.
-- isAnimated dispatches on controllers, not the Unwrap modifier wrapper.
fn lsyUVHasAnimatedPoints modifier =
(
    local queue=#(#(modifier,0)); local cursor=1; local scanned=0
    while cursor<=queue.count do
    (
        local item=queue[cursor][1]; local depth=queue[cursor][2]
        cursor+=1
        if depth>8 then throw "Animation inspection exceeded its supported depth."
        local count=item.numSubs
        for i=1 to count do
        (
            scanned+=1
            if scanned>200000 then throw "Animation inspection exceeded its supported size."
            local child=getSubAnim item i
            if child!=undefined do
            (
                local control=child.controller
                if control!=undefined then
                (
                    if isAnimated control then return true
                )
                else
                (
                    local value=child.value
                    if value!=undefined do
                        if isProperty value #numSubs do append queue #(value,depth+1)
                )
            )
        )
    )
    false
)

fn lsyUVCheckWriteContext node modifier =
(
    if animButtonState then throw "Auto Key is enabled; turn it off before UV coordinate tools."
    if theHold.Holding() then throw "Another Hold is active; finish the current operation first."
    if modifier.getEnableSoftSelection() then throw "Soft Selection is enabled; turn it off before UV coordinate tools."
    if lsyUVHasAnimatedPoints modifier then throw "Animated Unwrap data is not supported by coordinate tools."
    if (refs.dependentNodes modifier).count!=1 then throw "Shared/instanced Unwrap editing is not supported."
    if (refs.dependentNodes node.baseObject).count!=1 then throw "Shared/instanced base geometry editing is not supported."
    true
)

-- Retry deferred map restoration only in its actual active modifier context.
fn lsyUVRetryPendingBackground modifier =
(
    if lsyUVPendingBackgroundRestores==undefined then return true
    if modPanel.getCurrentObject()!=modifier then return false
    local ready=false
    try (ready=modifier.numberMaps()==modifier.texMapList.count+1) catch ()
    if not ready then return false
    local remaining=#()
    for entry in lsyUVPendingBackgroundRestores do
    (
        if entry[1]==modifier and entry[2]!=undefined and entry[3]!=undefined then
        (
            local issues=lsyUVRestoreBackgroundState modifier entry[2] entry[3]
            if issues.count>0 then append remaining #(entry[1],entry[2],entry[3],issues)
            else lsyUVStatus "보류했던 배경 복원을 처리했습니다. 외부 변경은 유지합니다."
        )
        else append remaining entry
    )
    lsyUVPendingBackgroundRestores=remaining
    true
)

fn lsyUVBind =
(
    if selection.count != 1 then
    (
        lsyUVStatus "오브젝트 하나만 선택하세요."
        return false
    )
    local n = selection[1]
    local m = modPanel.getCurrentObject()
    if m == undefined or classOf m != Unwrap_UVW then
    (
        lsyUVStatus "Modify 패널에서 사용할 Unwrap UVW를 먼저 클릭하세요."
        return false
    )
    local belongs = false
    for candidate in n.modifiers where candidate == m do belongs = true
    if not belongs then return false
    if not lsyUVIsolationRestore() then return false
    if not lsyUVRestore() then return false
    if not lsyUVBackgroundRestore() then return false
    lsyUVRetryPendingBackground m
    lsyUVSlotMaps = #()
    lsyUVSlotOwner = undefined
    lsyUVSlotIndices = #()
    LSYUVAdvanced.textureSlot.items = #()
    lsyUVLinkedDisplayState=undefined
    lsyUVFaceAutoPending=false
    lsyUVInvalidateAnalysis clearReference:true invalidateCoordinates:true
    lsyUVNode = n
    lsyUVMod = m
    lsyUVSyncDisplay()
    LSYUVTools.lockBackground.checked = false
    local channel = if m.getVC() then "Vertex Color" else
        (if m.getMapChannel() == 0 then "UV 1" else "UV " + m.getMapChannel() as string)
    LSYUVWorkbench.target.text = n.name + " | " + m.name + " | " + channel
    LSYUVAdvanced.materialInfo.text = "UV 면/점을 선택하고 선택 재질 조회를 누르세요."
    lsyUVBackgroundKey = undefined
    LSYUVTools.backgroundInfo.text = "Face 자동으로 배경을 선택한 뒤 고정 + 점 편집을 누르세요."
    if LSYUVTools.autoBackground.checked do lsyUVBackgroundRefresh()
    lsyUVStatus "대상을 연결했습니다. UV Editor 열기 또는 Face 자동 버튼을 사용하세요."
    true
)

fn lsyUVMode mode =
(
    if not lsyUVValid() then return false
    try
    (
        case mode of
        (
            #move: lsyUVMod.move()
            #rotate: lsyUVMod.rotate()
            #scale: lsyUVMod.scale()
            #moveU: lsyUVMod.moveH()
            #moveV: lsyUVMod.moveV()
            #scaleU: lsyUVMod.scaleH()
            #scaleV: lsyUVMod.scaleV()
            #freeform: lsyUVMod.setFreeFormMode true
            #pivot: lsyUVMod.snapPivot 1
        )
        lsyUVStatus ("기존 Max 도구 모드: " + mode as string)
        true
    )
    catch
    (
        lsyUVStatus "도구 전환 실패. 연결된 Unwrap의 UV Editor를 열고 재시도하세요."
        false
    )
)

-- BEGIN SHARED EDIT MATH
-- Generated from v1/edit_math.py; do not hand-edit this block.
fn lsyUVColorFloats red green blue = (point3 (red / 255.0) (green / 255.0) (blue / 255.0))
fn lsyUVCalculate positions operation amount =
(
    if positions.count == 0 then throw "Select UV points."
    if (findItem #(#scale,#scale_u,#scale_v,#snap_u,#snap_v) operation) > 0 and amount <= 0 then throw "Scale must be positive."
    if (findItem #(#scale,#scale_u,#scale_v) operation) > 0 and amount == 1 then return positions
    if operation == #rotate and (mod amount 360.0) == 0 then return positions
    local min_u = positions[1].x
    local max_u = min_u
    local min_v = positions[1].y
    local max_v = min_v
    for p in positions do
    (
        if p.x < min_u do min_u = p.x
        if p.x > max_u do max_u = p.x
        if p.y < min_v do min_v = p.y
        if p.y > max_v do max_v = p.y
    )
    local center_u = (min_u + max_u) / 2.0
    local center_v = (min_v + max_v) / 2.0
    local cosine = cos amount
    local sine = sin amount
    local levels_u = #()
    local levels_v = #()
    if operation == #distribute_u do (for p in positions do appendIfUnique levels_u p.x; sort levels_u)
    if operation == #distribute_v do (for p in positions do appendIfUnique levels_v p.y; sort levels_v)
    local result = #()
    for p in positions do
    (
        local u = p.x
        local v = p.y
        local w = p.z
        local distributed_u = u
        local distributed_v = v
        if levels_u.count > 1 do distributed_u = min_u+(max_u-min_u)*((findItem levels_u u)-1)/(levels_u.count-1)
        if levels_v.count > 1 do distributed_v = min_v+(max_v-min_v)*((findItem levels_v v)-1)/(levels_v.count-1)
        local snap_u = u
        local snap_v = v
        if operation == #snap_u do snap_u = (floor (u * amount + 0.5)) / amount
        if operation == #snap_v do snap_v = (floor (v * amount + 0.5)) / amount
        local q = case operation of
        (
            #align_u_min: point3 (min_u) (v) (w)
            #align_u_center: point3 (center_u) (v) (w)
            #align_u_max: point3 (max_u) (v) (w)
            #align_v_min: point3 (u) (min_v) (w)
            #align_v_center: point3 (u) (center_v) (w)
            #align_v_max: point3 (u) (max_v) (w)
            #nudge_u_plus: point3 (u + amount) (v) (w)
            #nudge_u_minus: point3 (u - amount) (v) (w)
            #nudge_v_plus: point3 (u) (v + amount) (w)
            #nudge_v_minus: point3 (u) (v - amount) (w)
            #rotate: point3 (center_u + cosine * (u - center_u) - sine * (v - center_v)) (center_v + sine * (u - center_u) + cosine * (v - center_v)) (w)
            #scale: point3 (center_u + (u - center_u) * amount) (center_v + (v - center_v) * amount) (w)
            #scale_u: point3 (center_u + (u - center_u) * amount) (v) (w)
            #scale_v: point3 (u) (center_v + (v - center_v) * amount) (w)
            #snap_u: point3 (snap_u) (v) (w)
            #snap_v: point3 (u) (snap_v) (w)
            #distribute_u: point3 (distributed_u) (v) (w)
            #distribute_v: point3 (u) (distributed_v) (w)
            #mirror_u: point3 (2 * center_u - u) (v) (w)
            #mirror_v: point3 (u) (2 * center_v - v) (w)
            #center_tile: point3 (u + 0.5 - center_u) (v + 0.5 - center_v) (w)
            default: throw "Unknown UV operation."
        )
        append result q
    )
    result
)
fn lsyUVNormalizeSlot value =
(
    local text = toLower (value as string)
    text = substituteString text "_" ""
    text = substituteString text " " ""
    text = substituteString text "/" ""
    text = substituteString text "-" ""
    text = substituteString text "(" ""
    text = substituteString text ")" ""
    text = substituteString text ":" ""
    text
)
fn lsyUVIsBaseSlot value =
(
    (findItem #("base","basecolor","basealbedo","basecoloralbedo","albedo","diffuse","diffusecolor","basecolordiffuse","basemap","basecolormap","basealbedomap","albedomap","diffusemap","diffusecolormap") (lsyUVNormalizeSlot value)) > 0
)
-- END SHARED EDIT MATH

fn lsyUVColorToUI p =
(
    local red = p.x * 255.0
    local green = p.y * 255.0
    local blue = p.z * 255.0
    if red < 0 do red = 0
    if red > 255 do red = 255
    if green < 0 do green = 0
    if green > 255 do green = 255
    if blue < 0 do blue = 0
    if blue > 255 do blue = 255
    color red green blue
)

fn lsyUVSyncDisplay =
(
    if lsyUVMod == undefined then return false
    lsyUVUISyncing = true
    local success = false
    try
    (
        LSYUVDisplay.tick.value = lsyUVGetVisual 1
        LSYUVDisplay.hit.value = lsyUVGetVisual 2
        LSYUVDisplay.selectedColor.color = lsyUVColorToUI (lsyUVGetVisual 3)
        LSYUVDisplay.edgeColor.color = lsyUVColorToUI (lsyUVGetVisual 4)
        LSYUVDisplay.openColor.color = lsyUVColorToUI (lsyUVGetVisual 5)
        LSYUVDisplay.gizmoColor.color = lsyUVColorToUI (lsyUVGetVisual 6)
        LSYUVDisplay.sharedColor.color = lsyUVColorToUI (lsyUVGetVisual 7)
        LSYUVDisplay.seams.checked = lsyUVGetVisual 8
        LSYUVDisplay.shared.checked = lsyUVGetVisual 9
        success = true
    )
    catch (lsyUVStatus ("표시 설정 읽기 오류: " + getCurrentException()))
    lsyUVUISyncing = false
    success
)

fn lsyUVApply =
(
    if not lsyUVValid() then return false
    try
    (
        if lsyUVOriginal == undefined do
        (
            local originals = #()
            for i = 1 to 9 do append originals (lsyUVGetVisual i)
            lsyUVOriginal = originals
            lsyUVApplied = #(undefined,undefined,undefined,undefined,undefined,undefined,undefined,undefined,undefined)
        )
        local pickerColors = #(LSYUVDisplay.selectedColor.color, LSYUVDisplay.edgeColor.color,
            LSYUVDisplay.openColor.color, LSYUVDisplay.gizmoColor.color, LSYUVDisplay.sharedColor.color)
        local values = #(LSYUVDisplay.tick.value, LSYUVDisplay.hit.value)
        for c in pickerColors do append values (lsyUVColorFloats c.r c.g c.b)
        append values LSYUVDisplay.seams.checked
        append values LSYUVDisplay.shared.checked
        for i = 1 to values.count do
        (
            lsyUVSetVisual i values[i]
            lsyUVApplied[i] = lsyUVGetVisual i
            if i >= 3 and i <= 7 do
                if (length (lsyUVApplied[i] - values[i])) > 0.01 then
                    throw "Color readback does not match normalized RGB."
        )
        lsyUVMod.UpdateView()
        LSYUVDisplay.displayInfo.text = "적용 확인 완료. 선택 점 색은 Vertex 모드의 선택한 점에 보입니다."
        lsyUVStatus "표시 색상/크기 적용 및 RGB 재조회 확인 완료."
        true
    )
    catch
    (
        LSYUVDisplay.liveDisplay.checked = false
        LSYUVDisplay.displayInfo.text = "적용 실패로 즉시 적용을 껐습니다. 표시 복원을 사용하세요."
        lsyUVStatus ("표시 적용 오류: " + getCurrentException())
        false
    )
)

fn lsyUVLiveDisplay =
(
    if lsyUVUISyncing or not LSYUVDisplay.liveDisplay.checked or lsyUVNode == undefined then return false
    lsyUVApply()
)

fn lsyUVContrastPreset =
(
    lsyUVUISyncing = true
    LSYUVDisplay.tick.value = 8
    LSYUVDisplay.hit.value = 8
    LSYUVDisplay.selectedColor.color = color 255 230 40
    LSYUVDisplay.edgeColor.color = color 120 210 255
    LSYUVDisplay.openColor.color = color 50 255 90
    LSYUVDisplay.gizmoColor.color = color 255 255 255
    LSYUVDisplay.sharedColor.color = color 255 100 220
    LSYUVDisplay.seams.checked = true
    LSYUVDisplay.shared.checked = false
    lsyUVUISyncing = false
    lsyUVApply()
)

-- Read incident faces by UV index, never by coincident coordinates.
-- Do not convert selection: that would interfere with ongoing native edits.
fn lsyUVSelectedFaces =
(
    local mode = lsyUVMod.getTVSubObjectMode()
    if mode == 3 then
    (
        lsyUVSelectionInfo = "면 선택"
        return (lsyUVMod.getSelectedFaces() as array)
    )
    if mode == 1 then
    (
        local vertices = lsyUVMod.getSelectedVerticesByNode lsyUVNode
        if (vertices as array).count == 0 then
        (
            lsyUVSelectionInfo = "선택된 UV 점 없음"
            return #()
        )
        local faceCount = lsyUVMod.numberPolygonsByNode lsyUVNode
        if faceCount != polyop.getNumFaces lsyUVNode.baseObject then
            throw "UV/base face counts differ; cannot resolve vertex materials safely."
        -- Bound work on the UI thread. Face mode remains available for larger scenes.
        if faceCount > 20000 then
        (
            lsyUVSelectionInfo = "점 재질 조회는 20,000면 이하에서 지원합니다. Face 모드를 사용하세요."
            return undefined
        )
        local faces = #()
        for face = 1 to faceCount do
        (
            local corners = lsyUVMod.numberPointsInFaceByNode face lsyUVNode
            local incident = false
            for corner = 1 to corners while not incident do
            (
                local index = lsyUVMod.getVertexIndexFromFaceByNode face corner lsyUVNode
                if index > 0 and index <= vertices.count do
                    if vertices[index] do incident = true
            )
            if incident do append faces face
        )
        lsyUVSelectionInfo = "점 선택 → " + faces.count as string + " 연결 면"
        return faces
    )
    lsyUVSelectionInfo = if mode == 2 then "엣지 자동 조회는 미지원입니다. 면 또는 점을 선택하세요." else "UV 점 또는 면을 선택하세요."
    undefined
)

-- Resolve only the Base Color/Diffuse branch. No arbitrary texture graph search.
-- A nested Multi/Sub uses the same actual face ID at each level.
fn lsyUVFormatIDs ids =
(
    local text = ""
    for i = 1 to ids.count do
    (
        if i > 1 do text += ", "
        text += ids[i] as string
    )
    text
)

fn lsyUVBaseMap material =
(
    local isPBR = matchPattern (toLower (classOf material as string)) pattern:"*pbr*"
    if not isPBR do
    (
        if (isProperty material #base_color_map) and (isProperty material #base_color_map_on) then
        (
            if not material.base_color_map_on then return #(undefined, "Base Color 맵이 꺼져 있습니다.")
            return #(material.base_color_map, "Base Color")
        )
        if (isProperty material #diffuseMap) and (isProperty material #diffuseMapEnable) then
        (
            if not material.diffuseMapEnable then return #(undefined, "Diffuse 맵이 꺼져 있습니다.")
            return #(material.diffuseMap, "Diffuse")
        )
    )
    -- Scripted PBR wrappers may not expose the Physical/Standard property aliases.
    -- Ask the public material API for semantic, nonlocalized slot names (Max 2022+).
    local candidates = #()
    local slotCount = getNumSubTexmaps material
    for i = 1 to slotCount do
    (
        local slotName = getSubTexmapSlotName material i localizedName:false
        if lsyUVIsBaseSlot slotName do
        (
            local map = getSubTexmap material i
            if map != undefined do appendIfUnique candidates map
        )
    )
    -- Also accept explicitly named Base/Albedo map parameters of scripted materials.
    for propName in getPropNames material do
    (
        if lsyUVIsBaseSlot propName do
        (
            local map = getProperty material propName
            if map != undefined and (isKindOf map TextureMap) do appendIfUnique candidates map
        )
    )
    if candidates.count == 1 then return #(candidates[1], "Base/Albedo 슬롯")
    if candidates.count > 1 then return #(undefined, "Base/Albedo 후보가 여러 개입니다. 재질 슬롯을 직접 선택하세요.")
    #(undefined, "Base/Albedo 맵을 찾지 못했습니다. 재질 슬롯 목록을 직접 확인하세요.")
)

fn lsyUVResolveID rootMaterial faceID =
(
    local material = rootMaterial
    local visited = #()
    local slots = #()
    local depth = 0
    while material != undefined and (isProperty material #materialIDList) do
    (
        depth += 1
        if depth > 8 or (findItem visited material) > 0 then
            return #(undefined, "재질 연결이 반복되거나 너무 깊습니다.", undefined)
        append visited material
        local matching = #()
        for i = 1 to material.materialIDList.count do
            if material.materialIDList[i] == faceID do append matching i
        if matching.count != 1 then
            return #(undefined, "해당 ID의 하위 재질이 없거나 중복되어 있습니다.", undefined)
        local slot = matching[1]
        if slot > material.materialList.count then
            return #(undefined, "하위 재질 슬롯이 유효하지 않습니다.", undefined)
        if isProperty material #mapEnabled do
            if slot <= material.mapEnabled.count do
                if not material.mapEnabled[slot] then
                    return #(undefined, "하위 재질이 비활성화되어 있습니다.", undefined)
        append slots slot
        material = material.materialList[slot]
    )
    if material == undefined then return #(undefined, "오브젝트에 사용할 재질이 없습니다.", undefined)
    local base = lsyUVBaseMap material
    local map = base[1]
    if map == undefined then return #(undefined, base[2], material)
    if classOf map != Bitmaptexture then
        return #(undefined, "직접 연결된 Bitmap만 지원합니다. 수동 이미지 선택을 사용하세요.", material)
    local slotInfo = if slots.count == 0 then "단일 재질" else "슬롯 " + (lsyUVFormatIDs slots)
    #(map, "ID " + faceID as string + " | " + slotInfo + " | " + base[2], material)
)

fn lsyUVMaterial =
(
    if not lsyUVValid() then return false
    try
    (
        if classOf lsyUVNode.baseObject != Editable_Poly or lsyUVNode.modifiers.count != 1 then
        (
            LSYUVAdvanced.materialInfo.text = "자동 조회는 Editable Poly + Unwrap 하나만 지원합니다."
            return false
        )
        local faces = lsyUVSelectedFaces()
        if faces == undefined then
        (
            LSYUVAdvanced.materialInfo.text = lsyUVSelectionInfo
            return false
        )
        local ids = #()
        for face in faces do appendIfUnique ids (polyop.getFaceMatID lsyUVNode.baseObject face)
        sort ids
        if ids.count == 0 then
        (
            LSYUVAdvanced.materialInfo.text = "연결된 면이 없습니다. " + lsyUVSelectionInfo
            return true
        )
        if ids.count > 1 then
        (
            LSYUVAdvanced.materialInfo.text = "여러 재질 ID: " + (lsyUVFormatIDs ids) + ". 배경 유지.\n" + lsyUVSelectionInfo
            return true
        )
        local resolved = lsyUVResolveID lsyUVNode.material ids[1]
        local info = resolved[2]
        if resolved[1] != undefined do
        (
            info += "\n" + resolved[1].filename
            if not doesFileExist resolved[1].filename do info += " | 파일 없음"
        )
        LSYUVAdvanced.materialInfo.text = info + "\n" + lsyUVSelectionInfo
        lsyUVStatus "재질 조회 완료. 배경이나 재질은 변경하지 않았습니다."
        true
    )
    catch
    (
        LSYUVAdvanced.materialInfo.text = "재질 조회 실패. 변경된 데이터는 없습니다."
        false
    )
)

-- Map indices belong to the native Editor list, never to Material IDs.
-- texMapList is the documented texture-map array (Max 8+).
-- Resolve actual entries, including addMap reusing an existing image.
-- The native dropdown has a leading special entry; texMapList[1] is index 2.
-- Max 2023 runtime evidence: list=8, dropdown=9, dropdown 6 displayed list[5].
fn lsyUVNativeMapIndices =
(
    local maps=lsyUVMod.texMapList
    local names=dotNetObject "System.String[]" maps.count
    for i=1 to maps.count do names.SetValue (if maps[i]==undefined then "" else maps[i].name) (i-1)
    local bridge=lsyUVGetFilterBridge()
    try (bridge.Maps names (lsyUVMod.getCurrentMap())) catch
    (
        local result=lsyUVNativeUI "maps"
        local array=dotNetObject "System.Int64[]" result.count
        for i=1 to result.count do array.SetValue (result[i] as integer64) (i-1)
        array
    )
)
fn lsyUVDropdownIndex listIndex =
(
    local count=lsyUVMod.texMapList.count
    if listIndex<1 or listIndex>count then throw "Invalid texture-list index."
    if lsyUVMod.numberMaps()==count+1 then return listIndex+1
    local mapping=lsyUVNativeMapIndices()
    local index=mapping.GetValue (listIndex-1)
    if index<1 then throw "Requested map is absent from current native texture dropdown."
    index as integer
)
fn lsyUVMapAtDropdown dropdownIndex =
(
    local maps=lsyUVMod.texMapList
    if lsyUVMod.numberMaps()==maps.count+1 then
    (
        local index=dropdownIndex-1
        return (if index>=1 and index<=maps.count then maps[index] else undefined)
    )
    local mapping=lsyUVNativeMapIndices()
    local matches=#()
    for i=1 to maps.count where (mapping.GetValue (i-1))==dropdownIndex do append matches maps[i]
    if matches.count==1 then matches[1] else undefined
)

fn lsyUVMapIndex map register:false =
(
    local maps = lsyUVMod.texMapList
    local index = findItem maps map
    if index > 0 then return (lsyUVDropdownIndex index)
    if classOf map == Bitmaptexture then
    (
        local matches = #()
        for i = 1 to maps.count do
            if maps[i] != undefined and classOf maps[i] == Bitmaptexture do
                if stricmp maps[i].filename map.filename == 0 do append matches i
        if matches.count == 1 then return (lsyUVDropdownIndex matches[1])
    )
    if not register then return 0
    lsyUVMod.addMap map
    -- addMap may append, reuse, or rebuild entries; inspect the result.
    index = lsyUVMapIndex map register:false
    if index == 0 then
        throw ("Registered image was not uniquely resolved in texMapList; list=" + lsyUVMod.texMapList.count as string + ", dropdown=" + lsyUVMod.numberMaps() as string)
    index
)

fn lsyUVBackgroundRestore =
(
    if lsyUVBackgroundOriginal == undefined then return true
    local issues = lsyUVRestoreBackgroundState lsyUVMod lsyUVBackgroundOriginal lsyUVBackgroundApplied
    local allOK = issues.count == 0
    for issue in issues do lsyUVStatus ("배경 복원: " + issue)
    if allOK then
    (
        lsyUVBackgroundOriginal = undefined
        lsyUVBackgroundApplied = undefined
        lsyUVBackground = undefined
        lsyUVBackgroundKey = undefined
        lsyUVBackgroundSummary = ""
        try (LSYUVTools.backgroundInfo.text = "원래 배경 설정을 복원했습니다.") catch ()
    )
    else
    (
        if lsyUVPendingBackgroundRestores==undefined do lsyUVPendingBackgroundRestores=#()
        append lsyUVPendingBackgroundRestores #(lsyUVMod,lsyUVBackgroundOriginal,lsyUVBackgroundApplied,issues)
        lsyUVBackgroundOriginal=undefined
        lsyUVBackgroundApplied=undefined
        lsyUVStatus "복원 불가 항목은 현재 배경을 유지하고 기록했습니다. 재연결은 계속합니다."
    )
    true
)

fn lsyUVEditorReady =
(
    -- numberMaps is backed by the Editor control, not the persistent texture array.
    -- A negative value is an unavailable UI, never a map count or an offset.
    local ready=false
    try (ready=lsyUVMod.numberMaps()>0 and lsyUVMod.numberMatIDs()>0) catch ()
    ready
)

fn lsyUVPrepareCustomBackground =
(
    if not lsyUVEditorReady() then throw "UV Editor is not ready; open it and wait for its map list."
    lsyUVBackgroundStage="prepare native background"
    local modifier=lsyUVMod
    local index=modifier.getMatID()
    local auto=modifier.getAutoBackground()
    local changed=index!=1 or auto
    if changed do
    (
        if lsyUVFilterState==undefined do lsyUVFilterState=#(modifier,index,index)
        if lsyUVNativeAutoState==undefined do lsyUVNativeAutoState=#(modifier,auto,auto)
        modifier.SetAutoBackGround false
        lsyUVNativeAutoState[3]=false
        modifier.setMatID 1
        lsyUVFilterState[3]=1
        if modifier.getMatID()!=1 or modifier.getAutoBackground() then throw "Could not reset native filter/auto background."
        modifier.updateMap()
        modifier.UpdateView()
        lsyUVBackgroundKey=undefined
    )
    -- A filtered dropdown cannot be compared with the full texture list.
    -- Validate the map adapter now, before addMap/SetCurrentMap/image writes.
    local failure=undefined
    try
    (
        lsyUVBackgroundStage="read prepared texture list"
        if modifier.numberMaps()!=modifier.texMapList.count+1 do lsyUVNativeMapIndices()
    ) catch (failure=getCurrentException())
    if failure!=undefined do
    (
        if changed do lsyUVIsolationRestore()
        throw failure
    )
    true
)

fn lsyUVSetBackground map key description =
(
    try
    (
        lsyUVPrepareCustomBackground()
        if lsyUVBackgroundOriginal == undefined do
        (
            local oldIndex = lsyUVMod.getCurrentMap()
            local oldMap = lsyUVMapAtDropdown oldIndex
            -- Read all restore values before any write.
            lsyUVBackgroundOriginal = #(oldMap, oldIndex, lsyUVMod.getShowMap(), lsyUVMod.getAutoBackground())
        )
        if lsyUVBackgroundApplied == undefined do lsyUVBackgroundApplied = #(undefined, undefined, undefined, undefined)
        lsyUVMod.setAutoBackground false
        lsyUVBackgroundApplied[3] = false
        local index = lsyUVMapIndex map register:true
        if index < 1 or index > lsyUVMod.numberMaps() then
            throw "Texture-list index is outside the native dropdown; automatic tracking stopped."
        lsyUVMod.SetCurrentMap index
        lsyUVBackgroundApplied[1] = lsyUVMapAtDropdown index
        lsyUVBackgroundApplied[4] = lsyUVMod.numberMaps()
        local actualIndex = lsyUVMod.getCurrentMap()
        if actualIndex < 1 or actualIndex > lsyUVMod.numberMaps() then
            throw "Native Editor did not select a valid map index."
        if actualIndex != index then
            throw "Native Editor selected a different map; automatic tracking stopped."
        lsyUVMod.setShowMap true
        lsyUVBackgroundApplied[2] = true
        lsyUVMod.updateMap()
        lsyUVMod.UpdateView()
        lsyUVBackground = map
        lsyUVBackgroundKey = key
        lsyUVBackgroundSummary = description + "\n" + map.filename
        LSYUVTools.backgroundInfo.text = lsyUVBackgroundSummary
        true
    )
    catch
    (
        lsyUVBackgroundKey = undefined
        LSYUVTools.autoBackground.checked = false
        LSYUVTools.backgroundInfo.text = "배경 API 오류로 자동 추적을 중지했습니다. 원래 배경 복원을 사용하세요."
        lsyUVStatus ("Background error: " + getCurrentException())
        false
    )
)

fn lsyUVKeyEqual first second =
(
    if first == undefined or second == undefined then return false
    if first.count != second.count then return false
    for i = 1 to first.count where first[i] != second[i] do return false
    true
)

fn lsyUVImage path =
(
    local stamp = getFileModDate path
    for entry in lsyUVImageCache do
        if stricmp entry[1] path == 0 and entry[2] == stamp do return entry[3]
    local image = bitmaptexture filename:path
    append lsyUVImageCache #(path, stamp, image)
    image
)

fn lsyUVFilePath path =
(
    if doesFileExist path then return path
    local resolved = undefined
    -- Reuse the host's texture search paths; never change the scene's filename.
    try (resolved = mapPaths.getFullFilePath path) catch ()
    if resolved != undefined do
        if doesFileExist resolved do return resolved
    undefined
)

fn lsyUVShowMaterialID faceID source =
(
    if lsyUVMod.getVC() then
    (
        lsyUVBackgroundMessage "Vertex Color 채널입니다. UV 텍스처 배경을 적용하지 않았습니다."
        return false
    )
    local resolved = lsyUVResolveID lsyUVNode.material faceID
    local map = resolved[1]
    if map == undefined then
    (
        lsyUVBackgroundMessage ("배경 유지: " + resolved[2])
        return false
    )
    local filePath = lsyUVFilePath map.filename
    if filePath == undefined then
    (
        lsyUVBackgroundMessage "이미지 파일을 찾을 수 없습니다. 배경을 유지합니다."
        return false
    )
    local key = #(source, faceID, lsyUVNode.material, resolved[3], map, filePath, getFileModDate filePath, lsyUVMod.getMapChannel())
    local description = source + " | " + resolved[2] + " | 원본 Bitmap"
    local editChannel = lsyUVMod.getMapChannel()
    if editChannel == 0 do editChannel = 1
    if isProperty map #coords do
        if isProperty map.coords #mapChannel do
            if map.coords.mapChannel != editChannel do
                description += " | 채널 다름: 텍스처 " + map.coords.mapChannel as string + ", 편집 " + editChannel as string
    if not (lsyUVKeyEqual key lsyUVBackgroundKey) or lsyUVBackground == undefined then
    (
        local image = lsyUVImage filePath
        lsyUVSetBackground image key description
    )
    else
    (
        lsyUVBackgroundSummary = description + "\n" + filePath
        LSYUVTools.backgroundInfo.text = lsyUVBackgroundSummary
        true
    )
)

fn lsyUVSameSelection first second =
(
    (first-second).numberSet == 0 and (second-first).numberSet == 0
)

-- BEGIN NATIVE FILTER BRIDGE
fn lsyUVGetFilterBridge =
(
    if lsyUVFilterBridgeVersion != 2 do lsyUVFilterBridge = undefined
    if lsyUVFilterBridge != undefined then return lsyUVFilterBridge
    local provider = dotNetObject "Microsoft.CSharp.CSharpCodeProvider"
    local options = dotNetObject "System.CodeDom.Compiler.CompilerParameters"
    options.GenerateInMemory = true
    options.ReferencedAssemblies.Add "System.dll"
    local sources = dotNetObject "System.String[]" 1
    sources.SetValue "using System;\nusing System.Collections.Generic;\nusing System.Runtime.InteropServices;\nusing System.Text;\nusing System.Text.RegularExpressions;\n\n// Read only: discovers actual Material ID labels. All writes use documented Unwrap API.\npublic static class LSYUVFilterBridgeV0112 {\n    delegate bool EnumProc(IntPtr hwnd, IntPtr param);\n    [StructLayout(LayoutKind.Sequential)] struct Rect { public int Left, Top, Right, Bottom; }\n    [DllImport(\"user32.dll\")] static extern bool EnumWindows(EnumProc proc, IntPtr param);\n    [DllImport(\"user32.dll\")] static extern bool EnumChildWindows(IntPtr hwnd, EnumProc proc, IntPtr param);\n    [DllImport(\"user32.dll\")] static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);\n    [DllImport(\"user32.dll\", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder text, int max);\n    [DllImport(\"user32.dll\")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);\n    [DllImport(\"user32.dll\", CharSet=CharSet.Unicode)] static extern IntPtr SendMessage(IntPtr hwnd, int msg, IntPtr a, IntPtr b);\n    [DllImport(\"user32.dll\", CharSet=CharSet.Unicode)] static extern IntPtr SendMessage(IntPtr hwnd, int msg, IntPtr a, StringBuilder b);\n    public static long[] Find(int x,int y,int w,int h,int[] ids) {\n        var matches = new List<long[]>();\n        uint process = (uint)System.Diagnostics.Process.GetCurrentProcess().Id;\n        EnumWindows(delegate(IntPtr window,IntPtr arg) {\n            uint pid; GetWindowThreadProcessId(window,out pid);\n            if(pid!=process) return true;\n            Rect r; if(!GetWindowRect(window,out r)) return true;\n            // Match dropdown contents, not cached editor bounds (DPI/window state changes them).\n            EnumChildWindows(window,delegate(IntPtr child,IntPtr ignored) {\n                var type=new StringBuilder(256); GetClassName(child,type,256);\n                if(type.ToString().IndexOf(\"combo\",StringComparison.OrdinalIgnoreCase)<0) return true;\n                int count=SendMessage(child,0x146,IntPtr.Zero,IntPtr.Zero).ToInt32();\n                if(count!=ids.Length+1) return true;\n                var slots=new Dictionary<int,int>();\n                for(int i=1;i<count;i++) {\n                    int length=SendMessage(child,0x149,new IntPtr(i),IntPtr.Zero).ToInt32();\n                    if(length<0 || length>1024) return true;\n                    var label=new StringBuilder(length+1);\n                    SendMessage(child,0x148,new IntPtr(i),label);\n                    var numbers=Regex.Matches(label.ToString(),@\"\\d+\");\n                    int id;\n                    if(numbers.Count!=1 || !Int32.TryParse(numbers[0].Value,out id) || Array.IndexOf(ids,id)<0 || slots.ContainsKey(id)) return true;\n                    slots.Add(id,i);\n                }\n                var result=new long[ids.Length+2]; result[0]=child.ToInt64();\n                result[1]=SendMessage(child,0x147,IntPtr.Zero,IntPtr.Zero).ToInt64();\n                for(int i=0;i<ids.Length;i++) result[i+2]=slots[ids[i]];\n                matches.Add(result); return true;\n            },IntPtr.Zero);\n            return true;\n        },IntPtr.Zero);\n        if(matches.Count!=1) throw new InvalidOperationException(\"Cannot uniquely read the UV Editor Material ID dropdown. Open the native Editor; current filter preserved.\");\n        return matches[0];\n    }\n    public static long[] Maps(string[] names,int apiCurrent) {\n        var matches=new List<long[]>();\n        uint process=(uint)System.Diagnostics.Process.GetCurrentProcess().Id;\n        EnumWindows(delegate(IntPtr window,IntPtr arg) {\n            uint pid; GetWindowThreadProcessId(window,out pid); if(pid!=process) return true;\n            EnumChildWindows(window,delegate(IntPtr child,IntPtr ignored) {\n                var type=new StringBuilder(256); GetClassName(child,type,256);\n                if(type.ToString().IndexOf(\"combo\",StringComparison.OrdinalIgnoreCase)<0) return true;\n                int count=SendMessage(child,0x146,IntPtr.Zero,IntPtr.Zero).ToInt32();\n                if(count<1 || count>names.Length+3) return true;\n                int selected=Selected(child.ToInt64());\n                int offset=apiCurrent==selected ? 0 : apiCurrent==selected+1 ? 1 : -1;\n                if(offset<0) return true;\n                var result=new long[names.Length]; int found=0;\n                for(int i=0;i<count;i++) {\n                    int length=SendMessage(child,0x149,new IntPtr(i),IntPtr.Zero).ToInt32();\n                    if(length<0 || length>2048) return true;\n                    var text=new StringBuilder(length+1); SendMessage(child,0x148,new IntPtr(i),text);\n                    string label=text.ToString().Trim(); int match=-1;\n                    for(int j=0;j<names.Length;j++) {\n                        string name=names[j];\n                        if(String.IsNullOrEmpty(name)) continue;\n                        if(label.Equals(name,StringComparison.OrdinalIgnoreCase) ||\n                            (label.StartsWith(name,StringComparison.OrdinalIgnoreCase) && label.Length>name.Length && !Char.IsLetterOrDigit(label[name.Length]))) {\n                            if(match>=0) return true;\n                            match=j;\n                        }\n                    }\n                    if(match>=0) {\n                        if(result[match]!=0 || i+offset<1) return true;\n                        result[match]=i+offset; found++;\n                    }\n                }\n                if(found>0) matches.Add(result);\n                return true;\n            },IntPtr.Zero); return true;\n        },IntPtr.Zero);\n        if(matches.Count!=1) throw new InvalidOperationException(\"Cannot uniquely read native texture dropdown; current background preserved.\");\n        return matches[0];\n    }\n    public static int Selected(long hwnd) {\n        return SendMessage(new IntPtr(hwnd),0x147,IntPtr.Zero,IntPtr.Zero).ToInt32();\n    }\n}\n" 0
    local result = provider.CompileAssemblyFromSource options sources
    provider.Dispose()
    if result.Errors.HasErrors then throw (result.Errors.Item[0].ErrorText)
    lsyUVFilterBridge = dotNetClass "LSYUVFilterBridgeV0112"
    lsyUVFilterBridgeVersion = 2
    lsyUVFilterBridge
)
-- END NATIVE FILTER BRIDGE

fn lsyUVIsolationRestore =
(
    if lsyUVMod!=undefined and (lsyUVFilterState!=undefined or lsyUVNativeAutoState!=undefined) do
    (
        local ready=false
        try (ready=lsyUVMod.numberMaps()>0) catch ()
        if not ready then return false
    )
    -- Only migrate a legacy selected-face filter; no new selection writes.
    if lsyUVIsolation != undefined do
    (
        try
        (
            local legacy = lsyUVIsolation
            if legacy[2].getFilterSelected() do legacy[2].setFilterSelected legacy[3]
            lsyUVIsolation = undefined
        )
        catch (lsyUVStatus ("이전 선택 필터 복원 오류: " + getCurrentException()))
    )
    if lsyUVNativeAutoState!=undefined do
    (
        try
        (
            if lsyUVNativeAutoState[1].getAutoBackground()==lsyUVNativeAutoState[3] do lsyUVNativeAutoState[1].SetAutoBackGround lsyUVNativeAutoState[2]
            lsyUVNativeAutoState=undefined
        )
        catch (lsyUVStatus ("순정 자동 배경 복원 오류: "+getCurrentException()); return false)
    )
    if lsyUVFilterState == undefined then return true
    try
    (
        local state = lsyUVFilterState
        if state[1].getMatID() == state[3] do
        (
            if state.count>=4 and lsyUVNode!=undefined and state[1]==lsyUVMod then
                lsyUVNativeUI "select_id" target:state[4]
            else state[1].setMatID (amax 1 state[2])
        )
        state[1].UpdateView()
        lsyUVFilterState = undefined
        true
    )
    catch (lsyUVStatus ("ID 필터 복원 오류: " + getCurrentException()); false)
)
-- BEGIN QT FILTER BRIDGE
fn lsyUVQtReadFilter ids target =
(
    lsyUVQtIDs=ids
    lsyUVQtTarget=target
    lsyUVQtMapping=undefined
    lsyUVQtError=""
    python.Execute "\"\"\"Find the native Qt Material ID dropdown without changing scene selection.\"\"\"\nimport re\n\n\ndef parse_id_label(label):\n    # Read a numeric ID field, never a number embedded in a texture filename.\n    match = re.match(r'^\\s*(?:(?:material|mat)?\\s*id\\s*[:#]?\\s*)?(\\d+)(?:\\s*$|\\s*[-:(\\[]\\s*[^.]*$)', label, re.I)\n    return int(match.group(1)) if match else None\n\n\ndef find_filter(widgets, ids):\n    expected = set(ids)\n    matches = []\n    sizes = []\n    for widget in widgets:\n        if not widget.isVisible():\n            continue\n        sizes.append(widget.count())\n        if widget.count() < len(expected)+1:\n            continue\n        slots = {}\n        specials = 0\n        for i in range(widget.count()):\n            label = widget.itemText(i)\n            value = parse_id_label(label)\n            if value is None:\n                if not re.search(r'\\d|[./\\\\]',label):\n                    specials += 1\n                    continue\n                break\n            if value == 0:\n                specials += 1\n                continue\n            if value in slots:\n                break\n            slots[value] = i\n        else:\n            # The native list may contain unused material IDs as well.\n            if specials == 1 and expected.issubset(slots):\n                matches.append((widget, slots))\n    exact = [entry for entry in matches if set(entry[1]) == expected]\n    if exact:\n        matches = exact\n    if len(matches) != 1:\n        raise RuntimeError('Qt ID matches=%d; expected=%s; visible combo counts=%s; total combos=%d; current filter preserved' %\n                           (len(matches), sorted(expected), sizes[:30], len(widgets)))\n    return matches[0]\n\n\ndef read_host_mapping():\n    from pymxs import runtime as rt\n    try:\n        from PySide2 import QtWidgets\n    except ImportError:\n        from PySide6 import QtWidgets\n    ids = [int(i) for i in rt.lsyUVQtIDs]\n    target = int(rt.lsyUVQtTarget)\n    widgets = []\n    for w in QtWidgets.QApplication.allWidgets():\n        if isinstance(w, QtWidgets.QComboBox):\n            widgets.append(w)\n        elif w.inherits('QComboBox'):\n            # Some C++ Max widgets are exposed initially as generic QWidget wrappers.\n            try:\n                try:\n                    from shiboken2 import getCppPointer, wrapInstance\n                except ImportError:\n                    from shiboken6 import getCppPointer, wrapInstance\n                widgets.append(wrapInstance(getCppPointer(w)[0], QtWidgets.QComboBox))\n            except (TypeError, RuntimeError):\n                pass\n    widget, slots = find_filter(widgets, ids)\n    selected = widget.currentIndex()\n    native = int(rt.lsyUVMod.getMatID())\n    offset = native-selected\n    if offset not in (0,1):\n        raise RuntimeError('Qt/native Material ID index mismatch; current filter preserved')\n    rt.lsyUVQtMapping = rt.Array(slots[target]+offset, selected, slots[target])\n\n\n# Executed only inside Max; importing for CPU tests has no host side effects.\ndef run_host():\n    from pymxs import runtime as rt\n    rt.lsyUVQtMapping = rt.undefined\n    rt.lsyUVQtError = ''\n    try:\n        read_host_mapping()\n    except Exception as exc:\n        rt.lsyUVQtError = str(exc)\n        try:\n            rt.lsyUVQtError += '; native IDs=%d current=%d' % (int(rt.lsyUVMod.numberMatIDs()), int(rt.lsyUVMod.getMatID()))\n        except Exception:\n            pass\n\nrun_host()\n"
    if lsyUVQtMapping==undefined then throw ("Qt ID filter: "+lsyUVQtError)
    lsyUVQtMapping
)
-- END QT FILTER BRIDGE

-- Select the actual native ID UI item; never infer sparse-ID order from a count.
fn lsyUVIsolateID id =
(
    local modifier=lsyUVMod
    local before=modifier.getMatID()
    local result=lsyUVNativeUI "select_id" target:id
    if lsyUVFilterState==undefined do lsyUVFilterState=#(modifier,before,result[2],result[1])
    lsyUVFilterState[3]=result[2]
    modifier.UpdateView()
    true
)

fn lsyUVBackgroundRefresh =
(
    if not LSYUVTools.autoBackground.checked or LSYUVTools.lockBackground.checked then return false
    if not lsyUVValid() then return false
    if not lsyUVEditorReady() then
    (
        lsyUVBackgroundMessage "UV Editor 대기 중. UV Editor를 열면 자동 배경을 다시 시도합니다."
        return true
    )
    try
    (
        if lsyUVFaceAutoPending do
        (
            lsyUVBackgroundStage="activate face mode"
            lsyUVMod.setTVSubObjectMode 3
            if lsyUVMod.getTVSubObjectMode()!=3 then throw "Face mode did not activate."
            lsyUVFaceAutoPending=false
        )
        lsyUVBackgroundStage="read selected faces"
        if classOf lsyUVNode.baseObject != Editable_Poly or lsyUVNode.modifiers.count != 1 then
        (
            LSYUVTools.backgroundInfo.text = "배경 유지: 자동 선택은 Editable Poly + Unwrap 하나만 지원합니다."
            return false
        )
        if lsyUVMod.getVC() then
        (
            LSYUVTools.backgroundInfo.text = "배경 유지: Vertex Color는 UV 텍스처 채널이 아닙니다."
            return false
        )
        if lsyUVMod.getTVSubObjectMode() != 3 then
        (
            lsyUVBackgroundMessage "점/엣지 편집 중: 현재 배경 유지. 이미지를 바꾸려면 Face 자동으로 돌아가세요."
            return true
        )
        local faces = lsyUVSelectedFaces()
        if faces == undefined then
        (
            LSYUVTools.backgroundInfo.text = "배경 유지: " + lsyUVSelectionInfo
            return false
        )
        local ids = #()
        for face in faces do appendIfUnique ids (polyop.getFaceMatID lsyUVNode.baseObject face)
        sort ids
        if ids.count == 0 then
        (
            lsyUVBackgroundMessage "선택한 면이 없습니다. 현재 배경을 유지합니다."
            return true
        )
        if ids.count > 1 then
        (
            lsyUVIsolationRestore()
            lsyUVBackgroundMessage ("여러 재질 ID 선택: " + (lsyUVFormatIDs ids) + ". 현재 배경 유지.")
            return true
        )
        local resolved=lsyUVResolveID lsyUVNode.material ids[1]
        local map=resolved[1]
        local displayKey=#(lsyUVNode,lsyUVMod,ids[1],lsyUVNode.material,lsyUVMod.getMapChannel(),currentTime,map)
        if map!=undefined do
        (
            append displayKey map.filename
            append displayKey (getFileModDate map.filename)
        )
        if lsyUVLinkedDisplayState!=undefined do
        (
            if lsyUVKeyEqual displayKey lsyUVLinkedDisplayState[1] do
                if lsyUVMod.getMatID()==lsyUVLinkedDisplayState[2] and lsyUVMod.getCurrentMap()==lsyUVLinkedDisplayState[3] and not lsyUVMod.getAutoBackground() then return true
        )
        -- Invalidate the inner cache after an external native display change.
        lsyUVBackgroundKey=undefined
        local showFilter=LSYUVTools.isolateID.checked
        -- Read ID capability before ID UI writes. Texture capability is checked
        -- inside PrepareCustomBackground AFTER resetting a reduced native list.
        try
        (
            if showFilter do lsyUVNativeUI "read_id" target:0
        )
        catch
        (
            local reason=getCurrentException()
            LSYUVTools.isolateID.checked=false
            showFilter=false
            lsyUVLinkedDisplayState=undefined
            lsyUVStatus ("ID 연동 보류; 자동 배경은 계속합니다. " + reason)
        )
        if showFilter do
        (
            try
            (
                local before=lsyUVMod.getMatID()
                local auto=lsyUVMod.getAutoBackground()
                if lsyUVNativeAutoState==undefined do lsyUVNativeAutoState=#(lsyUVMod,auto,auto)
                lsyUVMod.SetAutoBackGround false
                lsyUVNativeAutoState[3]=false
                local result=lsyUVNativeUI "select_id" target:0
                if lsyUVFilterState==undefined do lsyUVFilterState=#(lsyUVMod,before,result[2],result[1])
                lsyUVFilterState[3]=result[2]
                lsyUVBackgroundKey=undefined
            )
            catch
            (
                local reason=getCurrentException()
                LSYUVTools.autoBackground.checked=false
                lsyUVIsolationRestore()
                lsyUVStatus ("ID 표시 적용 중지: "+reason)
                return false
            )
        )
        lsyUVPrepareCustomBackground()
        local backgroundOK=lsyUVShowMaterialID ids[1] "자동"
        if backgroundOK and showFilter do
        (
            try
            (
                lsyUVIsolateID ids[1]
                local actual=lsyUVMapAtDropdown (lsyUVMod.getCurrentMap())
                if actual==undefined then throw "Could not verify visible background after filtering."
                if actual!=lsyUVBackgroundApplied[1] then throw "ID filter changed the selected background."
            )
            catch
            (
                local reason=getCurrentException()
                LSYUVTools.isolateID.checked=false
                try (lsyUVNativeUI "select_id" target:0) catch ()
                lsyUVPrepareCustomBackground()
                lsyUVBackgroundKey=undefined
                backgroundOK=lsyUVShowMaterialID ids[1] "자동"
                lsyUVStatus ("ID 연동 보류 / 배경만 유지: "+reason)
            )
        )
        if backgroundOK do lsyUVLinkedDisplayState=#(displayKey,lsyUVMod.getMatID(),lsyUVMod.getCurrentMap())
        backgroundOK


    )
    catch
    (
        LSYUVTools.autoBackground.checked = false
        local detail = getCurrentException()
        LSYUVTools.backgroundInfo.text = "자동 배경 중지: " + detail
        lsyUVStatus ("Auto background error ["+lsyUVBackgroundStage+"]: " + detail)
        false
    )
)

fn lsyUVManualBackground =
(
    if not lsyUVValid() then return false
    if LSYUVTools.lockBackground.checked then
    (
        LSYUVTools.backgroundInfo.text = "다른 이미지를 선택하려면 배경 고정을 해제하세요."
        return false
    )
    local path = getOpenFileName caption:"UV 배경 이미지 선택" types:"Images (*.png;*.jpg;*.jpeg;*.tga;*.bmp;*.tif;*.tiff;*.exr)|*.png;*.jpg;*.jpeg;*.tga;*.bmp;*.tif;*.tiff;*.exr|All files (*.*)|*.*|"
    if path == undefined then return false
    if not doesFileExist path then return false
    try
    (
        local image = lsyUVImage path
        if lsyUVSetBackground image #(#manual, path) "수동 이미지 | 원본 Bitmap" then
        (
            LSYUVTools.autoBackground.checked = false
            true
        )
        else false
    )
    catch
    (
        lsyUVStatus ("이미지를 불러올 수 없습니다: " + getCurrentException())
        false
    )
)

fn lsyUVManualID faceID =
(
    if not lsyUVValid() then return false
    if LSYUVTools.lockBackground.checked then
    (
        lsyUVBackgroundMessage "배경 고정을 먼저 해제하세요."
        return false
    )
    try
    (
        if lsyUVShowMaterialID faceID "ID 직접 지정" then
        (
            LSYUVTools.autoBackground.checked = false
            lsyUVStatus "지정한 ID의 배경 사용 중. 면의 Material ID는 변경하지 않았습니다."
            true
        )
        else false
    )
    catch
    (
        lsyUVStatus ("ID 배경 선택 오류: " + getCurrentException())
        false
    )
)

fn lsyUVLoadTextureSlots =
(
    if not lsyUVValid() then return false
    try
    (
        local resolved = lsyUVResolveID lsyUVNode.material LSYUVAdvanced.manualID.value
        local material = resolved[3]
        if material == undefined then
        (
            lsyUVBackgroundMessage resolved[2]
            return false
        )
        local names = #()
        lsyUVSlotMaps = #()
        lsyUVSlotIndices = #()
        lsyUVSlotOwner = #(lsyUVNode, lsyUVNode.material, material, LSYUVAdvanced.manualID.value)
        for i = 1 to (getNumSubTexmaps material) do
        (
            local map = getSubTexmap material i
            local name = getSubTexmapSlotName material i localizedName:false
            if map != undefined do
            (
                append lsyUVSlotMaps map
                append lsyUVSlotIndices i
                append names name
            )
        )
        lsyUVUISyncing = true
        LSYUVAdvanced.textureSlot.items = names
        LSYUVAdvanced.textureSlot.selection = 0
        lsyUVUISyncing = false
        lsyUVBackgroundMessage "선택한 ID의 맵 슬롯을 읽었습니다. 목록에서 원하는 슬롯을 직접 선택하세요."
        true
    )
    catch
    (
        lsyUVUISyncing = false
        lsyUVStatus ("재질 슬롯 조회 오류: " + getCurrentException())
        false
    )
)

fn lsyUVPickTextureSlot index =
(
    if lsyUVUISyncing then return false
    if index < 1 or index > lsyUVSlotMaps.count then return false
    if not lsyUVValid() then return false
    if LSYUVTools.lockBackground.checked then
    (
        lsyUVBackgroundMessage "수동 슬롯 배경을 쓰려면 배경 고정을 해제하세요."
        return false
    )
    if lsyUVSlotOwner == undefined or lsyUVSlotOwner[1] != lsyUVNode or lsyUVSlotOwner[2] != lsyUVNode.material or lsyUVSlotOwner[4] != LSYUVAdvanced.manualID.value then
    (
        lsyUVBackgroundMessage "대상/재질/ID가 바뀌었습니다. ID 맵 슬롯 목록을 다시 읽으세요."
        return false
    )
    local currentMaterial = (lsyUVResolveID lsyUVNode.material LSYUVAdvanced.manualID.value)[3]
    if currentMaterial != lsyUVSlotOwner[3] then
    (
        lsyUVBackgroundMessage "하위 재질이 바뀌었습니다. 슬롯 목록을 다시 읽으세요."
        return false
    )
    local slotIndex = lsyUVSlotIndices[index]
    if slotIndex > getNumSubTexmaps currentMaterial then return false
    local currentName = getSubTexmapSlotName currentMaterial slotIndex localizedName:false
    if currentName != LSYUVAdvanced.textureSlot.items[index] then
    (
        lsyUVBackgroundMessage "슬롯 구성이 바뀌었습니다. 슬롯 목록을 다시 읽으세요."
        return false
    )
    local map = getSubTexmap currentMaterial slotIndex
    if classOf map != Bitmaptexture then
    (
        lsyUVBackgroundMessage "이 슬롯은 직접 Bitmap이 아닙니다. 이미지 파일 선택을 사용하세요."
        return false
    )
    local filePath = lsyUVFilePath map.filename
    if filePath == undefined then
    (
        lsyUVBackgroundMessage "슬롯의 이미지 파일을 찾지 못했습니다."
        return false
    )
    try
    (
        local image = lsyUVImage filePath
        if lsyUVSetBackground image #(#slot, map) ("직접 선택한 슬롯: " + LSYUVAdvanced.textureSlot.items[index]) then
        (
            LSYUVTools.autoBackground.checked = false
            true
        )
        else false
    )
    catch (lsyUVStatus ("수동 슬롯 배경 오류: " + getCurrentException()); false)
)

fn lsyUVEditorAction action =
(
    if not lsyUVValid() then return false
    try
    (
        case action of
        (
            #open:
            (
                lsyUVMod.edit()
                lsyUVBackgroundKey = undefined
                if LSYUVTools.autoBackground.checked do lsyUVBackgroundRefresh()
            )
            #pan: (lsyUVMod.edit(); lsyUVMod.pan())
            #zoom: (lsyUVMod.edit(); lsyUVMod.zoom())
            #zoomRegion: (lsyUVMod.edit(); lsyUVMod.zoomRegion())
            #fit: lsyUVMod.fit()
            #vertexPreview:
            (
                lsyUVMod.edit()
                lsyUVMod.setTVSubObjectMode 1
            )
            #fitSelected:
            (
                local selected = #()
                case lsyUVMod.getTVSubObjectMode() of
                (
                    1: selected = lsyUVMod.getSelectedVertices() as array
                    2: selected = lsyUVMod.getSelectedEdges() as array
                    3: selected = lsyUVMod.getSelectedFaces() as array
                )
                if selected.count == 0 then
                (
                    lsyUVStatus "선택한 UV가 없습니다. 점/엣지/면을 선택한 뒤 화면을 맞추세요."
                    return false
                )
                lsyUVMod.fitSelected()
            )
        )
        lsyUVStatus "UV Editor 화면 조작 완료. UV 좌표는 변경하지 않았습니다."
        true
    )
    catch
    (
        lsyUVStatus ("UV Editor 조작 오류: " + getCurrentException())
        false
    )
)

fn lsyUVPinEdit mode =
(
    if not lsyUVValid() then return false
    local wasLocked = LSYUVTools.lockBackground.checked
    try
    (
        lsyUVMod.edit()
        if LSYUVTools.autoBackground.checked and not wasLocked do
            if not lsyUVBackgroundRefresh() then return false
        if LSYUVTools.isolateID.checked and lsyUVNativeAutoState!=undefined do
        (
            lsyUVMod.SetAutoBackGround false
            lsyUVNativeAutoState[3]=false
            LSYUVTools.lockBackground.checked=true
            lsyUVMod.setTVSubObjectMode mode
            lsyUVBackgroundMessage "현재 ID/이미지 고정 · 점/엣지 편집 중"
            return true
        )
        local current = lsyUVMapAtDropdown (lsyUVMod.getCurrentMap())
        if current == undefined or not lsyUVMod.getShowMap() then
        (
            lsyUVBackgroundMessage "Face에서 배경을 선택하거나 이미지 파일을 먼저 불러오세요."
            return false
        )
        -- The user may have chosen a different map directly in the native dropdown.
        -- Describe the actual visible map rather than a stale panel selection.
        if isProperty current #filename then
            lsyUVBackgroundSummary = "현재 UV 배경 | " + current.filename
        else lsyUVBackgroundSummary = "현재 UV 배경 | " + (classOf current as string)
        LSYUVTools.lockBackground.checked = true
        lsyUVMod.setTVSubObjectMode mode
        if lsyUVMod.getTVSubObjectMode() != mode then throw "UV selection mode did not change."
        lsyUVBackgroundMessage "배경 고정 · 편집 중. 다른 이미지는 Face 자동 버튼에서 선택하세요."
        lsyUVStatus "현재 배경을 고정하고 편집 모드로 전환했습니다."
        true
    )
    catch
    (
        LSYUVTools.lockBackground.checked = wasLocked
        lsyUVStatus ("편집 모드 전환 오류: " + getCurrentException())
        false
    )
)

fn lsyUVFaceAuto =
(
    if not lsyUVValid() then return false
    try
    (
        lsyUVMod.edit()
        lsyUVFaceAutoPending=true
        LSYUVTools.lockBackground.checked = false
        LSYUVTools.autoBackground.checked = true
        lsyUVBackgroundKey = undefined
        lsyUVStatus "Face 자동 배경 대기. UV Editor가 준비되면 선택 면에 맞춰 갱신합니다."
        true
    )
    catch
    (
        lsyUVStatus ("Face 자동 모드 오류: " + getCurrentException())
        false
    )
)

fn lsyUVSaveDiagnostics =
(
    if not lsyUVValid() then return false
    local path = getSaveFileName caption:"UV Workbench 진단 저장" types:"Text report (*.txt)|*.txt|"
    if path == undefined then return false
    local stream = undefined
    try
    (
        stream = createFile path
        format "LSY UV Workbench 0.15.1 diagnostic\nMax: %\n" (maxVersion() as string) to:stream
        format "Auto: % | Lock: % | UV selection mode: %\n" LSYUVTools.autoBackground.checked LSYUVTools.lockBackground.checked (lsyUVMod.getTVSubObjectMode()) to:stream
        format "Current dropdown: % | dropdown count: % | texture count: %\n" (lsyUVMod.getCurrentMap()) (lsyUVMod.numberMaps()) lsyUVMod.texMapList.count to:stream
        format "Texture IDs: %\n" lsyUVMod.texMapIDList to:stream
        format "Color representation: normalized RGB 0..1\n" to:stream
        for colorIndex = 3 to 7 do format "display-color[%]=%\n" colorIndex (lsyUVGetVisual colorIndex) to:stream
        local maps = lsyUVMod.texMapList
        local limit = maps.count
        if limit > 100 do limit = 100
        for i = 1 to limit do
        (
            local image = maps[i]
            local filename = "<no Bitmap>"
            if image != undefined do
                if (isProperty image #filename) do filename = (getFilenameFile image.filename) + (getFilenameType image.filename)
            format "list[%] dropdown[%] class=% file=%\n" i (i + 1) (classOf image) filename to:stream
        )
        if maps.count > limit do format "Remaining % texture entries omitted.\n" (maps.count - limit) to:stream
        -- Do not include object names, scene paths, or absolute texture paths.
        close stream
        stream = undefined
        lsyUVStatus "진단 파일을 저장했습니다. 파일명은 포함되며 전체 경로는 제외했습니다."
        true
    )
    catch
    (
        if stream != undefined do try (close stream) catch ()
        lsyUVStatus ("진단 저장 오류: " + getCurrentException())
        false
    )
)

fn lsyUVEdit operation amount =
(
    if not lsyUVValid() then return false
    try
    (
        if lsyUVMod.getTVSubObjectMode()!=1 then throw "Use Vertex mode for numeric coordinate tools."
        lsyUVCheckWriteContext lsyUVNode lsyUVMod
        local snapshot=lsyUVReadIslandSnapshot()
        local ids=lsyUVMod.getSelectedVerticesByNode lsyUVNode as array
        if ids.count==0 then throw "Select UV vertices first."
        local points=for index in ids collect snapshot[1][index]
        local targets=lsyUVCalculate points operation amount
        lsyUVCommitCoordinates snapshot ids targets ("LSY UV "+operation as string)
    ) catch (lsyUVStatus ("점 좌표 도구 오류: "+getCurrentException()); false)
)

-- BEGIN UV CONNECTIVITY
fn lsyUVIslandFromEdges vertexCount links picked used =
(
    local adjacency = for i=1 to vertexCount collect #()
    for edge in links do
    (
        append adjacency[edge[1]] edge[2]
        append adjacency[edge[2]] edge[1]
    )
    local result = picked * used
    local queue = result as array
    local cursor = 1
    while cursor <= queue.count do
    (
        for id in adjacency[queue[cursor]] where not result[id] do
        (
            result[id] = true
            append queue id
        )
        cursor += 1
    )
    result
)
-- END UV CONNECTIVITY

-- Close legacy companion windows when upgrading from 0.6/0.7.
global LSYUVPoints
try (destroyDialog LSYUVPoints) catch ()

-- BEGIN ISLAND ANALYSIS
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
-- END ISLAND ANALYSIS

-- BEGIN REPAIR MATH
fn lsyUVRunDensityMath =
(
    python.Execute "\"\"\"UV repair calculations. No host access on import; density uses geometry triangulation.\"\"\"\nimport math\nimport time\nfrom collections import Counter\n\n\ndef triangulate(points):\n    \"\"\"Ear clip a simple planar 3D polygon; reject degeneracy/non-planarity.\"\"\"\n    if len(points)>256:raise ValueError('Density supports at most 256 corners per face')\n    if len(points)<3: raise ValueError('A polygon needs at least three corners')\n    if not all(math.isfinite(x) for p in points for x in p):raise ValueError('Nonfinite geometry')\n    origin=points[0]\n    p=[tuple(v[k]-origin[k] for k in range(3)) for v in points]\n    normal=[sum(p[i][(k+1)%3]*p[(i+1)%len(p)][(k+2)%3]-p[i][(k+2)%3]*p[(i+1)%len(p)][(k+1)%3] for i in range(len(p))) for k in range(3)]\n    size=max(math.dist(a,b) for a in p for b in p)\n    length=math.sqrt(sum(x*x for x in normal))\n    if size<=0 or length<=size*size*1e-12:raise ValueError('Degenerate geometry face')\n    unit=[x/length for x in normal]\n    if any(abs(sum(v[k]*unit[k] for k in range(3)))>size*1e-6 for v in p):raise ValueError('Non-planar polygon is unsupported; triangulate the source explicitly')\n    drop=max(range(3),key=lambda k:abs(unit[k])); axes=[k for k in range(3) if k!=drop]\n    q=[(v[axes[0]],v[axes[1]]) for v in p]\n    def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])\n    signed=sum(q[i][0]*q[(i+1)%len(q)][1]-q[(i+1)%len(q)][0]*q[i][1] for i in range(len(q)))\n    sign=1 if signed>0 else -1; eps=size*size*1e-12\n    def on_segment(a,b,c):\n        return abs(cross(a,b,c))<=eps and min(a[0],b[0])-size*1e-12<=c[0]<=max(a[0],b[0])+size*1e-12 and min(a[1],b[1])-size*1e-12<=c[1]<=max(a[1],b[1])+size*1e-12\n    for i in range(len(q)):\n        for j in range(i+1,len(q)):\n            if j==i+1 or (i==0 and j==len(q)-1):continue\n            a,b=q[i],q[(i+1)%len(q)];c,d=q[j],q[(j+1)%len(q)]\n            if (cross(a,b,c)*cross(a,b,d)<0 and cross(c,d,a)*cross(c,d,b)<0) or any((on_segment(a,b,c),on_segment(a,b,d),on_segment(c,d,a),on_segment(c,d,b))):\n                raise ValueError('Self-intersecting or touching polygon')\n    remaining=list(range(len(q))); result=[]\n    while len(remaining)>3:\n        for at in range(len(remaining)):\n            a,b,c=remaining[at-1],remaining[at],remaining[(at+1)%len(remaining)]\n            if sign*cross(q[a],q[b],q[c])<=eps:continue\n            if any(all(sign*cross(q[x],q[y],q[k])>=-eps for x,y in ((a,b),(b,c),(c,a))) for k in remaining if k not in (a,b,c)):continue\n            result.append((a,b,c));del remaining[at];break\n        else:raise ValueError('Polygon cannot be triangulated without degeneracy')\n    if sign*cross(*(q[i] for i in remaining))<=eps:raise ValueError('Degenerate final triangle')\n    result.append(tuple(remaining));return result\n\n\ndef validate_native_triangles(corners, triangles):\n    \"\"\"Verify native corner coverage and internal edges, without choosing a diagonal.\"\"\"\n    if corners<3 or len(triangles)!=corners-2:\n        raise ValueError('Native triangle count does not match polygon corners')\n    edges=Counter(); oriented=Counter()\n    for triangle in triangles:\n        if len(triangle)!=3 or len(set(triangle))!=3 or any(i<0 or i>=corners for i in triangle):\n            raise ValueError('Invalid native triangle corner')\n        for a,b in zip(triangle,triangle[1:]+triangle[:1]):\n            edges[tuple(sorted((a,b)))]+=1;oriented[a,b]+=1\n    boundary={tuple(sorted((i,(i+1)%corners))) for i in range(corners)}\n    if {edge for edge,count in edges.items() if count==1}!=boundary or any(count not in (1,2) for count in edges.values()):\n        raise ValueError('Native triangles do not cover the polygon boundary')\n    for (a,b),count in edges.items():\n        if count==2 and (oriented[a,b]!=1 or oriented[b,a]!=1):\n            raise ValueError('Native triangles have inconsistent internal winding')\n    return triangles\n\n\ndef density(uv,world,faces,groups,width,height,triangles=None,partial=False,issues=None):\n    if width<=0 or height<=0:raise ValueError('Image dimensions must be positive')\n    records=[]\n    deadline=time.monotonic()+5.0\n    for group in groups:\n        uv_area=0.;world_area=0.;zero_uv=0;zero_world=0\n        try:\n            for face in group:\n                if time.monotonic()>deadline:raise ValueError('Density calculation exceeded the five-second budget')\n                uv_ids,geom_ids=faces[face]\n                if len(uv_ids)!=len(geom_ids):raise ValueError('UV/geometry corner mismatch')\n                poly=[world[i] for i in geom_ids]\n                tris=triangulate(poly) if triangles is None else validate_native_triangles(len(poly),triangles[face])\n                for ordinal,(a,b,c) in enumerate(tris,1):\n                    pa,pb,pc=(poly[i] for i in (a,b,c))\n                    ab=[pb[k]-pa[k] for k in range(3)];ac=[pc[k]-pa[k] for k in range(3)]\n                    area=math.sqrt(sum((ab[(k+1)%3]*ac[(k+2)%3]-ab[(k+2)%3]*ac[(k+1)%3])**2 for k in range(3)))*.5\n                    ua,ub,uc=(uv[uv_ids[i]] for i in (a,b,c))\n                    mapped=abs((ub[0]-ua[0])*(uc[1]-ua[1])-(ub[1]-ua[1])*(uc[0]-ua[0]))*.5\n                    if not math.isfinite(area) or not math.isfinite(mapped):\n                        raise ValueError('face=%d triangle=%d: nonfinite area' % (face+1,ordinal))\n                    if area==0:\n                        if mapped>0:raise ValueError('face=%d triangle=%d: world area=0 but UV area=%g' % (face+1,ordinal,mapped))\n                        zero_world+=1;continue\n                    if mapped==0:zero_uv+=1\n                    world_area+=area;uv_area+=mapped\n            if world_area<=0 or uv_area<=0:raise ValueError('Island density undefined: total world area=%g, UV area=%g' % (world_area,uv_area))\n            records.append((math.sqrt(width*height*uv_area/world_area),uv_area,world_area))\n            if issues is not None:issues.append('zero UV triangles=%d; zero world+UV triangles=%d' % (zero_uv,zero_world) if zero_uv or zero_world else '')\n        except ValueError as exc:\n            if not partial:raise\n            records.append(None)\n            if issues is not None:issues.append(str(exc))\n    return records\n\n\ndef run_host():\n    from pymxs import runtime as rt\n    rt.lsyUVRepairResult=rt.undefined;rt.lsyUVRepairError=''\n    try:\n        snapshot=rt.lsyUVRepairInput\n        uv=[(float(p.x),float(p.y),float(p.z)) for p in snapshot[0]]\n        world=[(float(p.x),float(p.y),float(p.z)) for p in snapshot[1]]\n        faces=[([int(i)-1 for i in f[0]],[int(i)-1 for i in f[1]]) for f in snapshot[2]]\n        groups=[[int(i)-1 for i in group] for group in snapshot[3]]\n        triangles=None\n        if len(snapshot)>6:\n            triangles=[[[int(i)-1 for i in triangle] for triangle in face] for face in snapshot[6]]\n        issues=[]\n        rows=density(uv,world,faces,groups,int(snapshot[4]),int(snapshot[5]),triangles,partial=True,issues=issues)\n        rt.lsyUVRepairResult=rt.Array(*(rt.Array(*(tuple(row)+ (issue,) if row is not None else (0.,0.,0.,issue))) for row,issue in zip(rows,issues)))\n    except Exception as exc:rt.lsyUVRepairError=str(exc)\n\nrun_host()\n"
)
-- END REPAIR MATH

-- BEGIN REPAIR COMMANDS
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
-- END REPAIR COMMANDS

fn lsyUVSelectNative action =
(
    if not lsyUVValid() then return false
    try
    (
        local node = lsyUVNode
        local modifier = lsyUVMod
        local mode=modifier.getTVSubObjectMode()
        if mode!=1 and not (mode==3 and action==#island) then
        (
            lsyUVStatus "섬 선택은 점/면 모드, 반전·해제는 점 모드에서 사용하세요."
            return false
        )
        local snapshot=lsyUVReadIslandSnapshot()
        local used=#{}
        for island in snapshot[3] do used+=island[2]
        local original=if mode==3 then modifier.getSelectedFacesByNode node else modifier.getSelectedVerticesByNode node
        local result=copy original
        case action of
        (
            #island:
            (
                result=#{}
                for island in snapshot[3] do
                (
                    local seeded=false
                    if mode==3 then
                        for f in island[1] where f<=original.count do if original[f] do seeded=true
                    else seeded=(original*island[2]).numberSet>0
                    if seeded do
                        if mode==3 then (for f in island[1] do result[f]=true) else result+=island[2]
                )
            )
            #invert: result=used-original
            #clear: result=#{}
        )
        if lsyUVSameSelection result original then return true
        undo "LSY UV selection" on
        (
            try
            (
                if mode==3 then modifier.selectFacesByNode result node else modifier.selectVerticesByNode result node
                local actual = if mode==3 then modifier.getSelectedFacesByNode node else modifier.getSelectedVerticesByNode node
                if not (lsyUVSameSelection actual result) then
                    throw ("Selection mismatch: requested=" + result.numberSet as string + ", actual=" + actual.numberSet as string + ", missing=" + ((result-actual) as array) as string + ", extra=" + ((actual-result) as array) as string)
            )
            catch
            (
                if mode==3 then modifier.selectFacesByNode original node else modifier.selectVerticesByNode original node
                throw()
            )
        )
        modifier.UpdateView()
        redrawViews()
        lsyUVStatus ("UV 점 " + result.numberSet as string + "개 선택. Ctrl+Z로 복원하세요.")
        true
    )
    catch (lsyUVStatus ("UV 선택 오류: " + getCurrentException()); false)
)

rollout LSYUVStack "Exact Stack" width:300 height:264
(
    label hint "기준 섬 · 검색 후보를 회전+이동으로 겹치기" pos:[8,8] width:280 height:20
    spinner widthPx "W" type:#integer range:[1,65536,1024] pos:[8,32] width:132 height:20
    spinner heightPx "H" type:#integer range:[1,65536,1024] pos:[150,32] width:132 height:20
    button calculate "Stack 계산" pos:[8,64] width:276 height:26 tooltip:"유사 섬 검색 결과로 Stack 변경을 계산합니다. Density와 별도의 계산 결과를 저장합니다."
    label info "유사 섬 검색 후 Stack을 계산하세요." pos:[8,100] width:280 height:44
    listbox rows "" pos:[8,148] width:276 height:3
    button applyPlan "Stack 적용" enabled:false pos:[8,218] width:132 height:26
    button discard "Stack 계산 취소" pos:[150,218] width:132 height:26
    fn clearPlan = (lsyUVStackPlan=undefined; applyPlan.enabled=false; rows.items=#(); info.text="유사 섬 검색 후 Stack을 계산하세요.")
    fn layout panelWidth =
    (
        local w=amax 280 panelWidth
        for control in #(hint,calculate,info,rows) do if isProperty control #width do control.width=w-22
        heightPx.pos=[8+(w-16)/2,32]
        discard.pos=[8+(w-16)/2,218]
    )
    on widthPx changed value do clearPlan()
    on heightPx changed value do clearPlan()
    on calculate pressed do lsyUVPlanStack()
    on applyPlan pressed do lsyUVApplyRepairPlan #stack
    on discard pressed do clearPlan()
)

rollout LSYUVTexel "Texel Density" width:300 height:340
(
    label hint "Raw UV · px/cm · 선택이 닿는 전체 섬" pos:[8,8] width:280 height:20
    spinner widthPx "W" type:#integer range:[1,65536,1024] pos:[8,32] width:132 height:20
    spinner heightPx "H" type:#integer range:[1,65536,1024] pos:[150,32] width:132 height:20
    button getDensity "밀도 조회" pos:[8,64] width:132 height:26
    button copyDensity "참조 밀도 복사" pos:[150,64] width:132 height:26 tooltip:"측정 밀도를 목표 숫자로 복사합니다. Stack 결과와는 무관합니다."
    spinner targetDensity "목표 px/cm" type:#float range:[0.000001,1000000000,10.24] pos:[8,100] width:276 height:20
    button calculate "밀도 변경 계산" pos:[8,130] width:276 height:26
    label info "밀도를 조회하거나 변경을 계산하세요." pos:[8,166] width:280 height:44
    listbox rows "" pos:[8,214] width:276 height:3
    button applyPlan "밀도 적용" enabled:false pos:[8,284] width:132 height:26
    button discard "밀도 계산 취소" pos:[150,284] width:132 height:26
    label rawNote "모든 대상에 위 W/H를 동일 적용" pos:[8,318] width:280 height:20
    fn clearPlan = (lsyUVDensityPlan=undefined; applyPlan.enabled=false; rows.items=#(); info.text="밀도를 조회하거나 변경을 계산하세요.")
    fn layout panelWidth =
    (
        local w=amax 280 panelWidth
        for control in #(hint,targetDensity,calculate,info,rows,rawNote) do if isProperty control #width do control.width=w-22
        heightPx.pos=[8+(w-16)/2,32]
        copyDensity.pos=[8+(w-16)/2,64]
        discard.pos=[8+(w-16)/2,284]
    )
    on widthPx changed value do clearPlan()
    on heightPx changed value do clearPlan()
    on targetDensity changed value do clearPlan()
    on getDensity pressed do lsyUVDensityGet()
    on copyDensity pressed do lsyUVDensityGet copyReference:true
    on calculate pressed do lsyUVPlanDensity()
    on applyPlan pressed do lsyUVApplyRepairPlan #density
    on discard pressed do clearPlan()
)

rollout LSYUVSimilar "유사 UV 섬 — Exact" width:300 height:290
(
    label help "같은 ID · 회전 허용 · 최대 128점/섬" pos:[8,8] width:280 height:24
    button capture "기준 섬 지정" pos:[8,38] width:130 height:26 tooltip:"한 섬의 면이나 점을 선택한 뒤 기준으로 지정합니다."
    button search "유사 섬 검색" pos:[150,38] width:130 height:26
    label info "기준 섬을 먼저 지정하세요." pos:[8,70] width:280 height:42
    listbox results "" pos:[8,112] width:280 height:6
    button selectResults "Exact 결과 선택" pos:[8,222] width:130 height:26 tooltip:"대칭이 아닌 Exact 후보의 면을 선택합니다. UV 좌표는 변경하지 않습니다."
    checkbox keepDirection "대칭 후보: 회전 없이 맞춤" checked:false pos:[8,252] width:278 height:26 tooltip:"대칭 섬에서 회전 0°인 대응이 정확히 하나일 때만 선택·Stack을 허용합니다. 체크 후 다시 검색하세요. 회전이 필요한 대칭 후보는 계속 제외합니다."
    fn layout panelWidth =
    (
        local w=amax 220 panelWidth
        if isProperty help #width do help.width=w-22
        if isProperty info #width do info.width=w-22
        if isProperty results #width do results.width=w-22
        search.pos=[8+(w-16)/2,38]
    )
    on keepDirection changed value do lsyUVInvalidateAnalysis()
    on capture pressed do lsyUVCaptureReference()
    on search pressed do lsyUVFindSimilar()
    on selectResults pressed do lsyUVSelectSimilarResults()
)

rollout LSYUVTools "배경" width:300 height:246
(
    checkbox autoBackground "면 자동 배경" checked:false pos:[8.0,8] width:110 height:26
    checkbox lockBackground "배경 고정" checked:false pos:[150.0,8] width:110 height:26
    button pinVertex "고정 · 점" tooltip:"현재 배경을 고정하고 Vertex 모드로 전환합니다." pos:[8.0,40] width:100 height:26
    button faceAuto "면 자동" tooltip:"Face 모드로 돌아가 선택 면의 배경을 자동으로 표시합니다." pos:[150.0,40] width:100 height:26
    button chooseImage "이미지 선택" tooltip:"배경 이미지 파일을 직접 선택합니다." pos:[8.0,72] width:100 height:26
    button restoreBackground "배경 복원" tooltip:"Workbench가 바꾼 배경을 원래 상태로 복원합니다." pos:[150.0,72] width:100 height:26
    edittext backgroundInfo "" text:"Face에서 이미지를 선택한 뒤 고정 + 점 편집을 누르세요." readOnly:true pos:[8.0,104] width:278.0 height:68
    checkbox isolateID "선택 ID의 UV만 표시" checked:false enabled:true tooltip:"실험 중인 ID 표시 연동입니다. 현재 Max에서 UI 조회 실패가 확인됐습니다. 켜면 배경과 함께 연동을 시도하고 실패 시 중지합니다." pos:[8.0,178] width:210 height:26
    button releaseIsolation "ID 필터 복원" tooltip:"Workbench가 바꾸기 전 ID 필터를 복원합니다. 원래 필터가 특정 ID였다면 전체 UV 표시가 아닐 수 있습니다." pos:[8.0,210] width:100 height:26
    fn layout panelWidth =
    (
        local w = amax 220 panelWidth
        autoBackground.pos = [8 + 0 * ((w-16)/2.0), 8]
        lockBackground.pos = [8 + 1 * ((w-16)/2.0), 8]
        pinVertex.pos = [8 + 0 * ((w-16)/2.0), 40]
        if isProperty pinVertex #width do pinVertex.width = amin 100 ((w-16)/2.0 - 6)
        faceAuto.pos = [8 + 1 * ((w-16)/2.0), 40]
        if isProperty faceAuto #width do faceAuto.width = amin 100 ((w-16)/2.0 - 6)
        chooseImage.pos = [8 + 0 * ((w-16)/2.0), 72]
        if isProperty chooseImage #width do chooseImage.width = amin 100 ((w-16)/2.0 - 6)
        restoreBackground.pos = [8 + 1 * ((w-16)/2.0), 72]
        if isProperty restoreBackground #width do restoreBackground.width = amin 100 ((w-16)/2.0 - 6)
        backgroundInfo.pos = [8 + 0 * ((w-16)/1.0), 104]
        if isProperty backgroundInfo #width do backgroundInfo.width = (w-16)/1.0 - 6
        isolateID.pos = [8 + 0 * ((w-16)/1.0), 178]
        releaseIsolation.pos = [8 + 0 * ((w-16)/1.0), 210]
        if isProperty releaseIsolation #width do releaseIsolation.width = amin 100 ((w-16)/1.0 - 6)
    )
    on pinVertex pressed do lsyUVPinEdit 1
    on faceAuto pressed do lsyUVFaceAuto()
    on autoBackground changed enabled do
    (
        lsyUVLinkedDisplayState=undefined
        lsyUVBackgroundKey = undefined
        if enabled then lsyUVBackgroundRefresh()
        else (lsyUVIsolationRestore(); lsyUVBackgroundMessage "자동 배경 꺼짐. 격리를 해제했습니다.")
    )
    on lockBackground changed locked do
    (
        if locked then lsyUVBackgroundMessage "배경 고정 중. 선택이 바뀌어도 이미지는 유지됩니다."
        else
        (
            lsyUVBackgroundKey = undefined
            if autoBackground.checked then lsyUVBackgroundRefresh()
            else lsyUVBackgroundMessage "배경 고정 해제. 수동 이미지 / ID 배경을 사용할 수 있습니다."
        )
    )
    on chooseImage pressed do lsyUVManualBackground()
    on restoreBackground pressed do
    (
        autoBackground.checked = false
        lockBackground.checked = false
        lsyUVIsolationRestore()
        lsyUVBackgroundRestore()
    )
    on isolateID changed enabled do
    (
        lsyUVLinkedDisplayState=undefined
        if enabled then (lsyUVBackgroundKey = undefined; lsyUVBackgroundRefresh())
        else lsyUVIsolationRestore()
    )
    on releaseIsolation pressed do (lsyUVLinkedDisplayState=undefined; isolateID.checked = false; lsyUVIsolationRestore())
)

rollout LSYUVAdvanced "재질 상세 (선택 사항)" width:300 height:214
(
    button pinEdge "고정 · 엣지" tooltip:"현재 배경을 고정하고 Edge 모드로 전환합니다." pos:[8.0,8] width:100 height:26
    button updateBackground "배경 갱신" tooltip:"선택 면의 배경을 다시 확인합니다." pos:[150.0,8] width:100 height:26
    spinner manualID "재질 ID" range:[1,60000,1] type:#integer fieldwidth:65 pos:[8.0,40] width:136.0 height:26
    button useManualID "ID 배경" tooltip:"입력한 재질 ID의 이미지 맵을 배경으로 사용합니다." pos:[150.0,40] width:100 height:26
    dropdownlist textureSlot "" items:#() pos:[8.0,72] width:136.0 height:44
    button loadSlots "맵 목록" tooltip:"입력한 재질 ID에서 사용 가능한 맵 슬롯을 조회합니다." pos:[150.0,72] width:100 height:26
    button refresh "선택 재질 조회" tooltip:"선택 재질 조회" pos:[8.0,122] width:100 height:26
    edittext materialInfo "" text:"Base/Albedo 슬롯을 우선 조회합니다." readOnly:true pos:[8.0,154] width:278.0 height:50
    fn layout panelWidth =
    (
        local w = amax 220 panelWidth
        pinEdge.pos = [8 + 0 * ((w-16)/2.0), 8]
        if isProperty pinEdge #width do pinEdge.width = amin 100 ((w-16)/2.0 - 6)
        updateBackground.pos = [8 + 1 * ((w-16)/2.0), 8]
        if isProperty updateBackground #width do updateBackground.width = amin 100 ((w-16)/2.0 - 6)
        manualID.pos = [8 + 0 * ((w-16)/2.0), 40]
        if isProperty manualID #width do manualID.width = (w-16)/2.0 - 6
        useManualID.pos = [8 + 1 * ((w-16)/2.0), 40]
        if isProperty useManualID #width do useManualID.width = amin 100 ((w-16)/2.0 - 6)
        textureSlot.pos = [8 + 0 * ((w-16)/2.0), 72]
        if isProperty textureSlot #width do textureSlot.width = (w-16)/2.0 - 6
        loadSlots.pos = [8 + 1 * ((w-16)/2.0), 72]
        if isProperty loadSlots #width do loadSlots.width = amin 100 ((w-16)/2.0 - 6)
        refresh.pos = [8 + 0 * ((w-16)/1.0), 122]
        if isProperty refresh #width do refresh.width = amin 100 ((w-16)/1.0 - 6)
        materialInfo.pos = [8 + 0 * ((w-16)/1.0), 154]
        if isProperty materialInfo #width do materialInfo.width = (w-16)/1.0 - 6
    )
    on pinEdge pressed do lsyUVPinEdit 2
    on useManualID pressed do lsyUVManualID manualID.value
    on textureSlot selected index do lsyUVPickTextureSlot index
    on loadSlots pressed do lsyUVLoadTextureSlots()
    on refresh pressed do lsyUVMaterial()
    on updateBackground pressed do
    (
        lsyUVBackgroundKey = undefined
        if LSYUVTools.autoBackground.checked then lsyUVBackgroundRefresh()
        else lsyUVBackgroundMessage "자동 배경을 켜거나 이미지 / 재질 ID를 직접 선택하세요."
    )
)

rollout LSYUVEditOps "정렬 · 좌표" width:300 height:390
(
    label section46 "좌표 — Vertex 모드" pos:[8.0,8] width:278.0 height:24
    label pointHelp "선택 점 편집 · Ctrl+Z 복원" pos:[8.0,38] width:278.0 height:24
    button alignUMin "U 최소" tooltip:"선택 점의 U 좌표를 최소 U에 정렬합니다." pos:[8.0,68] width:88.667 height:26
    button alignUCenter "U 중앙" tooltip:"선택 점의 U 좌표를 선택 범위 중심에 정렬합니다." pos:[102.667,68] width:88.667 height:26
    button alignUMax "U 최대" tooltip:"선택 점의 U 좌표를 최대 U에 정렬합니다." pos:[197.333,68] width:88.667 height:26
    button alignVMin "V 최소" tooltip:"선택 점의 V 좌표를 최소 V에 정렬합니다." pos:[8.0,100] width:88.667 height:26
    button alignVCenter "V 중앙" tooltip:"선택 점의 V 좌표를 선택 범위 중심에 정렬합니다." pos:[102.667,100] width:88.667 height:26
    button alignVMax "V 최대" tooltip:"선택 점의 V 좌표를 최대 V에 정렬합니다." pos:[197.333,100] width:88.667 height:26
    spinner rotateAngle "각도 °" range:[-3600,3600,90] type:#float fieldwidth:50 pos:[8.0,132] width:88.667 height:26
    button rotateMinus "회전 −" tooltip:"입력 각도의 음수 방향으로 선택 점을 회전합니다." pos:[102.667,132] width:88.667 height:26
    button rotatePlus "회전 +" tooltip:"입력 각도의 양수 방향으로 선택 점을 회전합니다." pos:[197.333,132] width:88.667 height:26
    spinner scalePercent "크기 %" range:[0.001,100000,100] type:#float fieldwidth:65 pos:[8.0,164] width:136.0 height:26
    button scaleApply "크기 적용" tooltip:"입력한 크기 %로 선택 점을 양 축 균일 확대/축소합니다." pos:[150.0,164] width:100 height:26
    button mirrorU "U 반전" tooltip:"선택 범위 중심에서 U 좌표를 반전합니다." pos:[8.0,196] width:88.667 height:26
    button mirrorV "V 반전" tooltip:"선택 범위 중심에서 V 좌표를 반전합니다." pos:[102.667,196] width:88.667 height:26
    button centerTile "중심 0.5" tooltip:"선택 범위 중심을 UV (0.5, 0.5)로 이동합니다." pos:[197.333,196] width:88.667 height:26
    spinner nudgeStep "이동량 UV" range:[0.000001,10,0.001] type:#float fieldwidth:65 pos:[8.0,228] width:278.0 height:26
    button nudgeUMinus "U −" tooltip:"미세 이동량만큼 U 음수 방향으로 이동합니다." pos:[8.0,260] width:65.0 height:26
    button nudgeUPlus "U +" tooltip:"미세 이동량만큼 U 양수 방향으로 이동합니다." pos:[79.0,260] width:65.0 height:26
    button nudgeVMinus "V −" tooltip:"미세 이동량만큼 V 음수 방향으로 이동합니다." pos:[150.0,260] width:65.0 height:26
    button nudgeVPlus "V +" tooltip:"미세 이동량만큼 V 양수 방향으로 이동합니다." pos:[221.0,260] width:65.0 height:26
    label section1743 "선택 — Vertex 모드" pos:[8.0,292] width:278.0 height:24
    button islandSelect "UV 섬 선택" tooltip:"선택 점에서 연결된 UV 섬 전체를 선택합니다. Seam은 건너지 않습니다." pos:[8.0,322] width:88.667 height:26
    button invertSelect "선택 반전" tooltip:"실제 사용되는 UV 점을 기준으로 선택을 반전합니다." pos:[102.667,322] width:88.667 height:26
    button clearSelect "선택 해제" tooltip:"UV 점 선택을 해제합니다." pos:[197.333,322] width:88.667 height:26
    button distributeU "U 균등 간격" pos:[8,358] width:100 height:26 tooltip:"최소/최대 U는 유지하고 서로 다른 U 위치 사이의 간격을 같게 합니다. 같은 U의 점들은 함께 유지됩니다."
    button distributeV "V 균등 간격" pos:[150,358] width:100 height:26 tooltip:"최소/최대 V는 유지하고 서로 다른 V 위치 사이의 간격을 같게 합니다. U/W는 유지합니다."
    fn layout panelWidth =
    (
        local w = amax 220 panelWidth
        section46.pos = [8 + 0 * ((w-16)/1.0), 8]
        if isProperty section46 #width do section46.width = (w-16)/1.0 - 6
        pointHelp.pos = [8 + 0 * ((w-16)/1.0), 38]
        if isProperty pointHelp #width do pointHelp.width = (w-16)/1.0 - 6
        alignUMin.pos = [8 + 0 * ((w-16)/3.0), 68]
        if isProperty alignUMin #width do alignUMin.width = amin 100 ((w-16)/3.0 - 6)
        alignUCenter.pos = [8 + 1 * ((w-16)/3.0), 68]
        if isProperty alignUCenter #width do alignUCenter.width = amin 100 ((w-16)/3.0 - 6)
        alignUMax.pos = [8 + 2 * ((w-16)/3.0), 68]
        if isProperty alignUMax #width do alignUMax.width = amin 100 ((w-16)/3.0 - 6)
        alignVMin.pos = [8 + 0 * ((w-16)/3.0), 100]
        if isProperty alignVMin #width do alignVMin.width = amin 100 ((w-16)/3.0 - 6)
        alignVCenter.pos = [8 + 1 * ((w-16)/3.0), 100]
        if isProperty alignVCenter #width do alignVCenter.width = amin 100 ((w-16)/3.0 - 6)
        alignVMax.pos = [8 + 2 * ((w-16)/3.0), 100]
        if isProperty alignVMax #width do alignVMax.width = amin 100 ((w-16)/3.0 - 6)
        rotateAngle.pos = [8 + 0 * ((w-16)/3.0), 132]
        if isProperty rotateAngle #width do rotateAngle.width = (w-16)/3.0 - 6
        rotateMinus.pos = [8 + 1 * ((w-16)/3.0), 132]
        if isProperty rotateMinus #width do rotateMinus.width = amin 100 ((w-16)/3.0 - 6)
        rotatePlus.pos = [8 + 2 * ((w-16)/3.0), 132]
        if isProperty rotatePlus #width do rotatePlus.width = amin 100 ((w-16)/3.0 - 6)
        scalePercent.pos = [8 + 0 * ((w-16)/2.0), 164]
        if isProperty scalePercent #width do scalePercent.width = (w-16)/2.0 - 6
        scaleApply.pos = [8 + 1 * ((w-16)/2.0), 164]
        if isProperty scaleApply #width do scaleApply.width = amin 100 ((w-16)/2.0 - 6)
        mirrorU.pos = [8 + 0 * ((w-16)/3.0), 196]
        if isProperty mirrorU #width do mirrorU.width = amin 100 ((w-16)/3.0 - 6)
        mirrorV.pos = [8 + 1 * ((w-16)/3.0), 196]
        if isProperty mirrorV #width do mirrorV.width = amin 100 ((w-16)/3.0 - 6)
        centerTile.pos = [8 + 2 * ((w-16)/3.0), 196]
        if isProperty centerTile #width do centerTile.width = amin 100 ((w-16)/3.0 - 6)
        nudgeStep.pos = [8 + 0 * ((w-16)/1.0), 228]
        if isProperty nudgeStep #width do nudgeStep.width = (w-16)/1.0 - 6
        nudgeUMinus.pos = [8 + 0 * ((w-16)/4.0), 260]
        if isProperty nudgeUMinus #width do nudgeUMinus.width = amin 100 ((w-16)/4.0 - 6)
        nudgeUPlus.pos = [8 + 1 * ((w-16)/4.0), 260]
        if isProperty nudgeUPlus #width do nudgeUPlus.width = amin 100 ((w-16)/4.0 - 6)
        nudgeVMinus.pos = [8 + 2 * ((w-16)/4.0), 260]
        if isProperty nudgeVMinus #width do nudgeVMinus.width = amin 100 ((w-16)/4.0 - 6)
        nudgeVPlus.pos = [8 + 3 * ((w-16)/4.0), 260]
        if isProperty nudgeVPlus #width do nudgeVPlus.width = amin 100 ((w-16)/4.0 - 6)
        section1743.pos = [8 + 0 * ((w-16)/1.0), 292]
        if isProperty section1743 #width do section1743.width = (w-16)/1.0 - 6
        islandSelect.pos = [8 + 0 * ((w-16)/3.0), 322]
        if isProperty islandSelect #width do islandSelect.width = amin 100 ((w-16)/3.0 - 6)
        invertSelect.pos = [8 + 1 * ((w-16)/3.0), 322]
        if isProperty invertSelect #width do invertSelect.width = amin 100 ((w-16)/3.0 - 6)
        clearSelect.pos = [8 + 2 * ((w-16)/3.0), 322]
        if isProperty clearSelect #width do clearSelect.width = amin 100 ((w-16)/3.0 - 6)
        distributeU.pos = [8 + 0 * ((w-16)/2.0), 358]
        if isProperty distributeU #width do distributeU.width = amin 100 ((w-16)/2.0 - 6)
        distributeV.pos = [8 + 1 * ((w-16)/2.0), 358]
        if isProperty distributeV #width do distributeV.width = amin 100 ((w-16)/2.0 - 6)
    )
    on distributeU pressed do lsyUVEdit #distribute_u 0
    on distributeV pressed do lsyUVEdit #distribute_v 0
    on alignUMin pressed do lsyUVEdit #align_u_min 0
    on alignUCenter pressed do lsyUVEdit #align_u_center 0
    on alignUMax pressed do lsyUVEdit #align_u_max 0
    on alignVMin pressed do lsyUVEdit #align_v_min 0
    on alignVCenter pressed do lsyUVEdit #align_v_center 0
    on alignVMax pressed do lsyUVEdit #align_v_max 0
    on rotateMinus pressed do lsyUVEdit #rotate (-rotateAngle.value)
    on rotatePlus pressed do lsyUVEdit #rotate rotateAngle.value
    on scaleApply pressed do lsyUVEdit #scale (scalePercent.value / 100.0)
    on mirrorU pressed do lsyUVEdit #mirror_u 0
    on mirrorV pressed do lsyUVEdit #mirror_v 0
    on centerTile pressed do lsyUVEdit #center_tile 0
    on nudgeUMinus pressed do lsyUVEdit #nudge_u_minus nudgeStep.value
    on nudgeUPlus pressed do lsyUVEdit #nudge_u_plus nudgeStep.value
    on nudgeVMinus pressed do lsyUVEdit #nudge_v_minus nudgeStep.value
    on nudgeVPlus pressed do lsyUVEdit #nudge_v_plus nudgeStep.value
    on islandSelect pressed do lsyUVSelectNative #island
    on invertSelect pressed do lsyUVSelectNative #invert
    on clearSelect pressed do lsyUVSelectNative #clear
)

rollout LSYUVTileOps "타일 · 픽셀 도구" width:300 height:232
(
    label section46 "타일 · 픽셀" pos:[8.0,8] width:278.0 height:24
    spinner textureWidth "이미지 폭 px" range:[1,65536,1024] type:#integer pos:[8.0,38] width:136.0 height:26
    spinner textureHeight "높이 px" range:[1,65536,1024] type:#integer pos:[150.0,38] width:136.0 height:26
    button snapU "U 픽셀 스냅" tooltip:"이미지 폭 기준으로 선택 점의 U를 가장 가까운 픽셀 경계에 맞춥니다." pos:[8.0,70] width:100 height:26
    button snapV "V 픽셀 스냅" tooltip:"이미지 높이 기준으로 선택 점의 V를 가장 가까운 픽셀 경계에 맞춥니다." pos:[150.0,70] width:100 height:26
    spinner tileStep "이동 타일 수" range:[1,1000,1] type:#integer pos:[8.0,102] width:278.0 height:26
    button tileLeft "U −타일" tooltip:"지정한 타일 수만큼 U 음수 방향으로 이동합니다. 0~1로 wrap하지 않습니다." pos:[8.0,134] width:65.0 height:26
    button tileRight "U +타일" tooltip:"지정한 타일 수만큼 U 양수 방향으로 이동합니다." pos:[79.0,134] width:65.0 height:26
    button tileDown "V −타일" tooltip:"지정한 타일 수만큼 V 음수 방향으로 이동합니다." pos:[150.0,134] width:65.0 height:26
    button tileUp "V +타일" tooltip:"지정한 타일 수만큼 V 양수 방향으로 이동합니다." pos:[221.0,134] width:65.0 height:26
    button scaleUExact "U 크기 적용" tooltip:"크기 %를 U 축에만 적용합니다. V는 유지합니다." pos:[8.0,166] width:100 height:26
    button scaleVExact "V 크기 적용" tooltip:"크기 %를 V 축에만 적용합니다. U는 유지합니다." pos:[150.0,166] width:100 height:26
    label tileHelp "폭/높이 직접 지정 · 타일 밖 UV 유지" pos:[8.0,198] width:278.0 height:24
    fn layout panelWidth =
    (
        local w = amax 220 panelWidth
        section46.pos = [8 + 0 * ((w-16)/1.0), 8]
        if isProperty section46 #width do section46.width = (w-16)/1.0 - 6
        textureWidth.pos = [8 + 0 * ((w-16)/2.0), 38]
        if isProperty textureWidth #width do textureWidth.width = (w-16)/2.0 - 6
        textureHeight.pos = [8 + 1 * ((w-16)/2.0), 38]
        if isProperty textureHeight #width do textureHeight.width = (w-16)/2.0 - 6
        snapU.pos = [8 + 0 * ((w-16)/2.0), 70]
        if isProperty snapU #width do snapU.width = amin 100 ((w-16)/2.0 - 6)
        snapV.pos = [8 + 1 * ((w-16)/2.0), 70]
        if isProperty snapV #width do snapV.width = amin 100 ((w-16)/2.0 - 6)
        tileStep.pos = [8 + 0 * ((w-16)/1.0), 102]
        if isProperty tileStep #width do tileStep.width = (w-16)/1.0 - 6
        tileLeft.pos = [8 + 0 * ((w-16)/4.0), 134]
        if isProperty tileLeft #width do tileLeft.width = amin 100 ((w-16)/4.0 - 6)
        tileRight.pos = [8 + 1 * ((w-16)/4.0), 134]
        if isProperty tileRight #width do tileRight.width = amin 100 ((w-16)/4.0 - 6)
        tileDown.pos = [8 + 2 * ((w-16)/4.0), 134]
        if isProperty tileDown #width do tileDown.width = amin 100 ((w-16)/4.0 - 6)
        tileUp.pos = [8 + 3 * ((w-16)/4.0), 134]
        if isProperty tileUp #width do tileUp.width = amin 100 ((w-16)/4.0 - 6)
        scaleUExact.pos = [8 + 0 * ((w-16)/2.0), 166]
        if isProperty scaleUExact #width do scaleUExact.width = amin 100 ((w-16)/2.0 - 6)
        scaleVExact.pos = [8 + 1 * ((w-16)/2.0), 166]
        if isProperty scaleVExact #width do scaleVExact.width = amin 100 ((w-16)/2.0 - 6)
        tileHelp.pos = [8 + 0 * ((w-16)/1.0), 198]
        if isProperty tileHelp #width do tileHelp.width = (w-16)/1.0 - 6
    )
    on snapU pressed do lsyUVEdit #snap_u textureWidth.value
    on snapV pressed do lsyUVEdit #snap_v textureHeight.value
    on tileLeft pressed do lsyUVEdit #nudge_u_minus tileStep.value
    on tileRight pressed do lsyUVEdit #nudge_u_plus tileStep.value
    on tileDown pressed do lsyUVEdit #nudge_v_minus tileStep.value
    on tileUp pressed do lsyUVEdit #nudge_v_plus tileStep.value
    on scaleUExact pressed do lsyUVEdit #scale_u (LSYUVEditOps.scalePercent.value / 100.0)
    on scaleVExact pressed do lsyUVEdit #scale_v (LSYUVEditOps.scalePercent.value / 100.0)
)

rollout LSYUVNativeOps "빠른 변환" width:300 height:200
(
    label section47 "기존 UV Editor 화면 도구" pos:[8.0,8] width:278.0 height:24
    button nativePan "화면 이동" tooltip:"기존 UV Editor의 화면 이동 도구를 활성화합니다." pos:[8.0,38] width:88.667 height:26
    button nativeZoom "확대/축소" tooltip:"기존 UV Editor의 확대/축소 도구를 활성화합니다." pos:[102.667,38] width:88.667 height:26
    button nativeRegion "영역 확대" tooltip:"기존 UV Editor의 영역 확대 도구를 활성화합니다." pos:[197.333,38] width:88.667 height:26
    label section358 "기존 Max 드래그 도구" pos:[8.0,70] width:278.0 height:24
    button move "이동" tooltip:"기존 UV Editor의 Move 도구를 활성화합니다." pos:[8.0,100] width:88.667 height:26
    button rotate "회전" tooltip:"기존 UV Editor의 Rotate 도구를 활성화합니다." pos:[102.667,100] width:88.667 height:26
    button scale "스케일" tooltip:"기존 UV Editor의 Scale 도구를 활성화합니다." pos:[197.333,100] width:88.667 height:26
    button moveU "U 이동" tooltip:"기존 U 이동 도구를 활성화합니다." pos:[8.0,132] width:65.0 height:26
    button moveV "V 이동" tooltip:"기존 V 이동 도구를 활성화합니다." pos:[79.0,132] width:65.0 height:26
    button scaleU "U 스케일" tooltip:"기존 U 스케일 도구를 활성화합니다." pos:[150.0,132] width:65.0 height:26
    button scaleV "V 스케일" tooltip:"기존 V 스케일 도구를 활성화합니다." pos:[221.0,132] width:65.0 height:26
    button freeform "Freeform" tooltip:"기존 Freeform 도구를 켭니다." pos:[8.0,164] width:100 height:26
    button pivot "피벗 중앙" tooltip:"기즈모 피벗을 선택 중심으로 맞춥니다." pos:[150.0,164] width:100 height:26
    fn layout panelWidth =
    (
        local w = amax 220 panelWidth
        section47.pos = [8 + 0 * ((w-16)/1.0), 8]
        if isProperty section47 #width do section47.width = (w-16)/1.0 - 6
        nativePan.pos = [8 + 0 * ((w-16)/3.0), 38]
        if isProperty nativePan #width do nativePan.width = amin 100 ((w-16)/3.0 - 6)
        nativeZoom.pos = [8 + 1 * ((w-16)/3.0), 38]
        if isProperty nativeZoom #width do nativeZoom.width = amin 100 ((w-16)/3.0 - 6)
        nativeRegion.pos = [8 + 2 * ((w-16)/3.0), 38]
        if isProperty nativeRegion #width do nativeRegion.width = amin 100 ((w-16)/3.0 - 6)
        section358.pos = [8 + 0 * ((w-16)/1.0), 70]
        if isProperty section358 #width do section358.width = (w-16)/1.0 - 6
        move.pos = [8 + 0 * ((w-16)/3.0), 100]
        if isProperty move #width do move.width = amin 100 ((w-16)/3.0 - 6)
        rotate.pos = [8 + 1 * ((w-16)/3.0), 100]
        if isProperty rotate #width do rotate.width = amin 100 ((w-16)/3.0 - 6)
        scale.pos = [8 + 2 * ((w-16)/3.0), 100]
        if isProperty scale #width do scale.width = amin 100 ((w-16)/3.0 - 6)
        moveU.pos = [8 + 0 * ((w-16)/4.0), 132]
        if isProperty moveU #width do moveU.width = amin 100 ((w-16)/4.0 - 6)
        moveV.pos = [8 + 1 * ((w-16)/4.0), 132]
        if isProperty moveV #width do moveV.width = amin 100 ((w-16)/4.0 - 6)
        scaleU.pos = [8 + 2 * ((w-16)/4.0), 132]
        if isProperty scaleU #width do scaleU.width = amin 100 ((w-16)/4.0 - 6)
        scaleV.pos = [8 + 3 * ((w-16)/4.0), 132]
        if isProperty scaleV #width do scaleV.width = amin 100 ((w-16)/4.0 - 6)
        freeform.pos = [8 + 0 * ((w-16)/2.0), 164]
        if isProperty freeform #width do freeform.width = amin 100 ((w-16)/2.0 - 6)
        pivot.pos = [8 + 1 * ((w-16)/2.0), 164]
        if isProperty pivot #width do pivot.width = amin 100 ((w-16)/2.0 - 6)
    )
    on nativePan pressed do lsyUVEditorAction #pan
    on nativeZoom pressed do lsyUVEditorAction #zoom
    on nativeRegion pressed do lsyUVEditorAction #zoomRegion
    on move pressed do lsyUVMode #move
    on rotate pressed do lsyUVMode #rotate
    on scale pressed do lsyUVMode #scale
    on moveU pressed do lsyUVMode #moveU
    on moveV pressed do lsyUVMode #moveV
    on scaleU pressed do lsyUVMode #scaleU
    on scaleV pressed do lsyUVMode #scaleV
    on freeform pressed do lsyUVMode #freeform
    on pivot pressed do lsyUVMode #pivot
)

rollout LSYUVDisplay "색상 · 표시" width:300 height:360
(
    label displayHelp "선택 점 색상 · Vertex 모드" pos:[8.0,8] width:278.0 height:24
    button viewVertices "Vertex 모드로 색상 확인" tooltip:"Vertex 모드로 색상 확인" pos:[8.0,38] width:100 height:26
    checkbox liveDisplay "색상·크기 즉시 적용" checked:true pos:[8.0,70] width:210 height:26
    spinner tick "선택 점 크기" range:[1,32,6] type:#integer fieldwidth:45 pos:[8.0,102] width:136.0 height:26
    spinner hit "선택 판정 크기" range:[1,32,6] type:#integer fieldwidth:45 pos:[150.0,102] width:136.0 height:26
    colorpicker selectedColor "선택 점" color:(color 255 230 40) pos:[8.0,134] width:136.0 height:26
    colorpicker edgeColor "일반 UV 선" color:(color 120 210 255) pos:[150.0,134] width:136.0 height:26
    colorpicker openColor "경계/Seam" color:(color 50 255 90) pos:[8.0,166] width:136.0 height:26
    colorpicker gizmoColor "기즈모" color:(color 255 255 255) pos:[150.0,166] width:136.0 height:26
    colorpicker sharedColor "공유 UV" color:(color 255 100 220) pos:[8.0,198] width:278.0 height:26
    checkbox seams "UV 경계선 표시" checked:true pos:[8.0,230] width:110 height:26
    checkbox shared "공유 UV 강조" checked:false pos:[150.0,230] width:110 height:26
    button contrast "고대비 프리셋" tooltip:"고대비 프리셋" pos:[8.0,262] width:100 height:26
    button sync "현재 설정 읽기" tooltip:"현재 설정 읽기" pos:[150.0,262] width:100 height:26
    button apply "표시 적용" tooltip:"표시 적용" pos:[8.0,294] width:100 height:26
    button restore "표시 복원" tooltip:"표시 복원" pos:[150.0,294] width:100 height:26
    label displayInfo "색상은 선택 점에 적용됩니다." pos:[8.0,326] width:278.0 height:24
    fn layout panelWidth =
    (
        local w = amax 220 panelWidth
        displayHelp.pos = [8 + 0 * ((w-16)/1.0), 8]
        if isProperty displayHelp #width do displayHelp.width = (w-16)/1.0 - 6
        viewVertices.pos = [8 + 0 * ((w-16)/1.0), 38]
        if isProperty viewVertices #width do viewVertices.width = amin 100 ((w-16)/1.0 - 6)
        liveDisplay.pos = [8 + 0 * ((w-16)/1.0), 70]
        tick.pos = [8 + 0 * ((w-16)/2.0), 102]
        if isProperty tick #width do tick.width = (w-16)/2.0 - 6
        hit.pos = [8 + 1 * ((w-16)/2.0), 102]
        if isProperty hit #width do hit.width = (w-16)/2.0 - 6
        selectedColor.pos = [8 + 0 * ((w-16)/2.0), 134]
        if isProperty selectedColor #width do selectedColor.width = (w-16)/2.0 - 6
        edgeColor.pos = [8 + 1 * ((w-16)/2.0), 134]
        if isProperty edgeColor #width do edgeColor.width = (w-16)/2.0 - 6
        openColor.pos = [8 + 0 * ((w-16)/2.0), 166]
        if isProperty openColor #width do openColor.width = (w-16)/2.0 - 6
        gizmoColor.pos = [8 + 1 * ((w-16)/2.0), 166]
        if isProperty gizmoColor #width do gizmoColor.width = (w-16)/2.0 - 6
        sharedColor.pos = [8 + 0 * ((w-16)/1.0), 198]
        if isProperty sharedColor #width do sharedColor.width = (w-16)/1.0 - 6
        seams.pos = [8 + 0 * ((w-16)/2.0), 230]
        shared.pos = [8 + 1 * ((w-16)/2.0), 230]
        contrast.pos = [8 + 0 * ((w-16)/2.0), 262]
        if isProperty contrast #width do contrast.width = amin 100 ((w-16)/2.0 - 6)
        sync.pos = [8 + 1 * ((w-16)/2.0), 262]
        if isProperty sync #width do sync.width = amin 100 ((w-16)/2.0 - 6)
        apply.pos = [8 + 0 * ((w-16)/2.0), 294]
        if isProperty apply #width do apply.width = amin 100 ((w-16)/2.0 - 6)
        restore.pos = [8 + 1 * ((w-16)/2.0), 294]
        if isProperty restore #width do restore.width = amin 100 ((w-16)/2.0 - 6)
        displayInfo.pos = [8 + 0 * ((w-16)/1.0), 326]
        if isProperty displayInfo #width do displayInfo.width = (w-16)/1.0 - 6
    )
    on tick changed value do lsyUVLiveDisplay()
    on hit changed value do lsyUVLiveDisplay()
    on selectedColor changed value do lsyUVLiveDisplay()
    on edgeColor changed value do lsyUVLiveDisplay()
    on openColor changed value do lsyUVLiveDisplay()
    on gizmoColor changed value do lsyUVLiveDisplay()
    on sharedColor changed value do lsyUVLiveDisplay()
    on seams changed value do lsyUVLiveDisplay()
    on shared changed value do lsyUVLiveDisplay()
    on contrast pressed do lsyUVContrastPreset()
    on viewVertices pressed do lsyUVEditorAction #vertexPreview
    on sync pressed do lsyUVSyncDisplay()
    on apply pressed do lsyUVApply()
    on restore pressed do
    (
        if lsyUVRestore() do lsyUVSyncDisplay()
    )
)

rollout LSYUVWorkbench "LSY UV Workbench | 0.15.1" width:330 height:760
(
    button bind "대상 연결" pos:[8,8] width:94 height:25
    button openEditor "UV Editor" pos:[108,8] width:94 height:25
    button diagnostics "진단 저장" pos:[208,8] width:94 height:25
    label target "대상을 먼저 연결하세요." pos:[8,38] width:300 height:24
    button fitAll "전체 UV 맞춤" pos:[8,65] width:144 height:25
    button fitSelected "선택 UV 맞춤" pos:[158,65] width:144 height:25
    subRollout pages "" pos:[6,98] width:318 height:600
    label status "대상 연결 후 면 자동 배경을 켜세요." pos:[8,710] width:308 height:42
    timer backgroundTimer interval:600 active:true
    local layoutReady = false
    local layoutBusy = false
    local lastLayoutSize = undefined
    fn layout size =
    (
        local w = amax 330 size.x
        local h = amax 420 size.y
        if size.x < 330 or size.y < 420 do setDialogSize LSYUVWorkbench [w,h]
        pages.width = w-12
        pages.height = h-156
        local children = #(LSYUVTools,LSYUVNativeOps,LSYUVSimilar,LSYUVStack,LSYUVTexel,LSYUVEditOps,LSYUVTileOps,LSYUVDisplay,LSYUVAdvanced)
        for child in children do
        (
            child.width = w-30
            child.layout (w-30)
        )
        target.width = w-16
        status.pos = [8,h-50]
        status.width = w-16
        lastLayoutSize = [w,h]
    )
    on LSYUVWorkbench open do
    (
        addSubRollout pages LSYUVTools
        addSubRollout pages LSYUVNativeOps rolledUp:true
        addSubRollout pages LSYUVSimilar
        addSubRollout pages LSYUVStack
        addSubRollout pages LSYUVTexel rolledUp:true
        addSubRollout pages LSYUVEditOps rolledUp:true
        addSubRollout pages LSYUVTileOps rolledUp:true
        addSubRollout pages LSYUVDisplay rolledUp:true
        addSubRollout pages LSYUVAdvanced rolledUp:true
        layoutReady = true
        layout (getDialogSize LSYUVWorkbench)
        lsyUVUISyncing = false
    )
    on LSYUVWorkbench resized size do if layoutReady and not layoutBusy do
    (
        layoutBusy = true
        try (layout size) catch (lsyUVStatus ("창 배치 오류: " + getCurrentException()))
        layoutBusy = false
    )
    on bind pressed do lsyUVBind()
    on openEditor pressed do lsyUVEditorAction #open
    on fitAll pressed do lsyUVEditorAction #fit
    on fitSelected pressed do lsyUVEditorAction #fitSelected
    on diagnostics pressed do lsyUVSaveDiagnostics()
    on backgroundTimer tick do
    (
        if layoutReady and not layoutBusy do
        (
            local actualSize = getDialogSize LSYUVWorkbench
            if actualSize != lastLayoutSize do
            (
                layoutBusy = true
                try (layout actualSize) catch (lsyUVStatus ("창 배치 오류: " + getCurrentException()))
                layoutBusy = false
            )
        )
        if LSYUVTools.autoBackground.checked and not LSYUVTools.lockBackground.checked and lsyUVNode != undefined do
        (
            if isValidNode lsyUVNode and selection.count == 1 then
            (
                if selection[1] == lsyUVNode and modPanel.getCurrentObject() == lsyUVMod then
                (
                    if not lsyUVBackgroundRefreshBusy do
                    (
                        lsyUVBackgroundRefreshBusy=true
                        try (lsyUVBackgroundRefresh()) catch
                        (
                            local reason=getCurrentException()
                            LSYUVTools.autoBackground.checked=false
                            lsyUVStatus ("자동 표시 중지: "+reason)
                        )
                        lsyUVBackgroundRefreshBusy=false
                    )
                )
                else lsyUVBackgroundMessage "자동 배경 일시 중지: 연결된 오브젝트와 Unwrap을 활성화하세요."
            )
            else lsyUVBackgroundMessage "자동 배경 일시 중지: 연결된 오브젝트가 선택되지 않았습니다."
        )
    )
    on LSYUVWorkbench close do
    (
        lsyUVUISyncing = true
        backgroundTimer.active = false
        lsyUVInvalidateAnalysis clearReference:true invalidateCoordinates:true
        lsyUVLinkedDisplayState=undefined
        lsyUVIsolationRestore()
        lsyUVBackgroundRestore()
        lsyUVRestore()
    )
)
createDialog LSYUVWorkbench style:#(#style_titlebar,#style_sysmenu,#style_minimizebox,#style_resizing)
lsyUVStatus "0.15.1 준비 완료. 세로 도구 패널 · 섹션을 펼쳐 사용하세요."
