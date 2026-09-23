# SPDX-License-Identifier: GPL-2.0
# Copyright (c) 2013-2026 Igor Pecovnik, igor@armbian.com
#
# gpt-shrink-entries: after the partition table is created, shrink the GPT
# partition-entry array to the number of partitions actually used.
#
# sfdisk creates a GPT with the default 128 partition entries at LBA 2..33
# (1 KiB .. 17 KiB). Some SoC boot flows require boot blobs in that low area
# (e.g. the Allwinner A733 BROM reads boot0 at sector 16 = 8 KiB), which would
# overwrite the GPT entries. Shrinking the entry array (the GPT header carries
# the real count, so this stays fully spec-compliant) keeps the entries below
# 8 KiB and lets boot0 and GPT coexist.

# @description Shrink the GPT entry array after partitioning, before the image
# is mounted/formatted. Only acts on GPT images.
function post_create_partitions__gpt_shrink_entries() {
	[[ "${IMAGE_PARTITION_TABLE}" == "gpt" ]] || return 0
	[[ -f "${SDCARD}.raw" ]] || return 0

	display_alert "Shrinking GPT partition entry array" "${SDCARD}.raw" "info"

	run_host_command_logged python3 - "${SDCARD}.raw" <<- 'PYEOF'
		import struct, sys, zlib

		path = sys.argv[1]
		SIG = b'EFI PART'
		with open(path, 'r+b') as f:
		    size = f.seek(0, 2)

		    # --- main GPT header (LBA 1) ---
		    f.seek(512)
		    hdr = bytearray(f.read(512))
		    if hdr[0:8] != SIG:
		        print("gpt-shrink-entries: no main GPT header, skipping", file=sys.stderr)
		        sys.exit(0)
		    hdr_size = struct.unpack_from('<I', hdr, 0x0C)[0]           # SizeOfHeader
		    entry_lba = struct.unpack_from('<Q', hdr, 0x48)[0]         # PartitionEntryLBA
		    num_entries = struct.unpack_from('<I', hdr, 0x50)[0]       # NumberOfPartitionEntries
		    entry_size = struct.unpack_from('<I', hdr, 0x54)[0]        # SizeOfPartitionEntry

		    f.seek(entry_lba * 512)
		    entries = bytearray(f.read(num_entries * entry_size))

		    # count used entries (a partition entry is used iff its type GUID != 0)
		    used = 0
		    for i in range(num_entries):
		        if entries[i * entry_size:i * entry_size + 16] != b'\x00' * 16:
		            used = i + 1
		    if used >= num_entries:
		        print(f"gpt-shrink-entries: {used}/{num_entries} entries, nothing to shrink")
		        sys.exit(0)

		    # zero the unused entries (keeps the area tidy; readers only see `used` entries)
		    for i in range(used, num_entries):
		        entries[i * entry_size:(i + 1) * entry_size] = b'\x00' * entry_size

		    entries_crc = zlib.crc32(bytes(entries[:used * entry_size])) & 0xffffffff
		    struct.pack_into('<I', hdr, 0x50, used)                      # NumberOfPartitionEntries
		    struct.pack_into('<I', hdr, 0x58, entries_crc)               # PartitionEntriesCRC32
		    struct.pack_into('<I', hdr, 0x10, 0)                         # zero CRC for computation
		    hdr_crc = zlib.crc32(bytes(hdr[:hdr_size])) & 0xffffffff     # CRC covers SizeOfHeader bytes
		    struct.pack_into('<I', hdr, 0x10, hdr_crc)

		    f.seek(512)
		    f.write(bytes(hdr))
		    f.seek(entry_lba * 512)
		    f.write(bytes(entries))

		    # --- backup GPT (header in the last sector) ---
		    f.seek(size - 512)
		    bhdr = bytearray(f.read(512))
		    if bhdr[0:8] == SIG:
		        bhdr_size = struct.unpack_from('<I', bhdr, 0x0C)[0]
		        bentry_lba = struct.unpack_from('<Q', bhdr, 0x48)[0]
		        struct.pack_into('<I', bhdr, 0x50, used)
		        struct.pack_into('<I', bhdr, 0x58, entries_crc)
		        struct.pack_into('<I', bhdr, 0x10, 0)
		        b_crc = zlib.crc32(bytes(bhdr[:bhdr_size])) & 0xffffffff
		        struct.pack_into('<I', bhdr, 0x10, b_crc)
		        f.seek(size - 512)
		        f.write(bytes(bhdr))
		        f.seek(bentry_lba * 512)
		        f.write(bytes(entries))

		    print(f"gpt-shrink-entries: shrunk GPT entries {num_entries} -> {used}")
		PYEOF
}
