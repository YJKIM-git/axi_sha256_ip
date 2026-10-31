import struct
import sys
from pathlib import Path

def preprocess_rsp_to_bin(rsp_path: Path, bin_path: Path) -> int:
    bit_len = None
    msg_bytes = None
    md_words = None
    vec_count = 0

    with rsp_path.open("r", encoding="utf-8") as fin, bin_path.open("wb") as fout:
        for raw_line in fin:
            line = raw_line.strip()
            if not line or line.startswith("#") or line.startswith("["):
                continue

            if line.startswith("Len"):
                bit_len = int(line.split("=")[1].strip())
            elif line.startswith("Msg"):
                hex_str = line.split("=")[1].strip()
                byte_len = bit_len // 8
                msg_bytes = bytes.fromhex(hex_str)[:byte_len] if byte_len > 0 else b""
            elif line.startswith("MD"):
                md_hex = line.split("=")[1].strip()
                md_raw = bytes.fromhex(md_hex)
                md_words = struct.unpack(">8I", md_raw)

                # Pack 40-byte header (bit_len, byte_len, 8x uint32 golden_md) + raw msg_bytes
                header = struct.pack("<II8I", bit_len, len(msg_bytes), *md_words)
                fout.write(header)
                if msg_bytes:
                    fout.write(msg_bytes)

                vec_count += 1
                bit_len = None
                msg_bytes = None
                md_words = None

    return vec_count

if __name__ == "__main__":
    targets = [
        ("SHA256ShortMsg.rsp", "SHORT_TV.BIN"),
        ("SHA256LongMsg.rsp", "LONG_TV.BIN"),
    ]
    for src_name, dst_name in targets:
        src = Path(src_name)
        dst = Path(dst_name)
        if src.exists():
            cnt = preprocess_rsp_to_bin(src, dst)
            print(f"[OK] {src_name} -> {dst_name} ({cnt} vectors, {dst.stat().st_size} bytes)")
        else:
            print(f"[WARN] {src_name} not found in current directory", file=sys.stderr)