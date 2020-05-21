################################################################################
# Address: 0x800882b0
################################################################################

.include "Common/Common.s"
.include "Playback/Playback.s"

.set REG_PDB_ADDRESS, 31
.set REG_SOUND_ID, 30 # from caller
.set REG_SFXDB_ADDRESS, 29
.set REG_WRITE_INDEX, 28

# I actually don't know if I need to include this, I can't get the second
# branch of the SFX_PlayCharacterVoiceSFX function to run at all so I'm not
# sure if this will ever even be hit... but here it is just in case, it's
# effectively a duplicate of the other function except it branches to a diff
# location

backup

lwz REG_PDB_ADDRESS, primaryDataBuffer(r13) # data buffer address
addi REG_SFXDB_ADDRESS, REG_PDB_ADDRESS, PDB_SFXDB_START

rlwinm REG_SOUND_ID, REG_SOUND_ID, 0, 0xFFFF # extract half word ID

lbz REG_WRITE_INDEX, SFXDB_WRITE_INDEX(REG_SFXDB_ADDRESS)
loadGlobalFrame r3
lwz r4, PDB_LATEST_FRAME(REG_PDB_ADDRESS)
cmpw r3, r4
bgt RESTORE_AND_EXIT # If new frame, skip check if we should play sound

CHECK_SOUND:
# First let's determine the write index for the current frame
loadGlobalFrame r3
lwz r4, PDB_LATEST_FRAME(REG_PDB_ADDRESS)
addi r4, r4, 1 # Simulate the latest frame being 1 frame ahead (would be the case for recording)

# If we are on the last frame that was run before a ffw, the following
# will equal 1 I believe. The ffw end frame was never actually processed
sub r3, r4, r3

lbz REG_WRITE_INDEX, SFXDB_WRITE_INDEX(REG_SFXDB_ADDRESS)
sub. REG_WRITE_INDEX, REG_WRITE_INDEX, r3
bge FETCH_LOG_ADDRESS
addi REG_WRITE_INDEX, REG_WRITE_INDEX, SOUND_STORAGE_FRAME_COUNT

FETCH_LOG_ADDRESS:
mulli r3, REG_WRITE_INDEX, SFXS_FRAME_SIZE
addi r6, REG_SFXDB_ADDRESS, SFXDB_FRAMES + SFXS_FRAME_STABLE_LOG
add r6, r6, r3

li r8, 0
b FIND_SOUND_LOOP_CONDITION
FIND_SOUND_LOOP_START:
mulli r3, r8, SFXS_ENTRY_SIZE
addi r5, r6, SFXS_LOG_ENTRIES
add r5, r5, r3

# Load sound ID and check if it is equal to this one
lhz r3, SFXS_ENTRY_SOUND_ID(r5)
cmpw REG_SOUND_ID, r3
beq SOUND_ALREADY_PLAYED

FIND_SOUND_LOOP_CONTINUE:
addi r8, r8, 1

FIND_SOUND_LOOP_CONDITION:
lbz r3, SFXS_LOG_INDEX(r6)
cmpw r8, r3
blt FIND_SOUND_LOOP_START

b RESTORE_AND_EXIT

SOUND_ALREADY_PLAYED:
# Skip destroy functions
restore
branch r12, 0x800882d0

RESTORE_AND_EXIT:
restore

EXIT:
addi r3, r31, 0