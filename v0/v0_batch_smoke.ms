/* Load the rollout in 3ds Max Batch without opening a dialog. */
global LSYV0_Batch = true
local sourcePath = getSourceFileName()
fileIn ((getFilenamePath sourcePath) + "LSY_UV_V0.ms")
format "LSY V0 MAXScript load PASS\n"
