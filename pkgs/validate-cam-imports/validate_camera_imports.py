import click
from pathlib import Path
from blake3 import blake3
from tqdm.contrib.concurrent import process_map

exts = ["jpg", "arw", "heif", "mp4"]
io_processes = 8


class bcolors:
    HEADER = "\033[95m"
    OKBLUE = "\033[94m"
    OKCYAN = "\033[96m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    ENDC = "\033[0m"
    BOLD = "\033[1m"
    UNDERLINE = "\033[4m"


def hash_file(file_path) -> str:
    hasher = blake3(max_threads=blake3.AUTO)
    hasher.update_mmap(file_path)
    return hasher.hexdigest()


@click.command()
@click.argument("src_dir", type=click.Path(exists=True), default=".")
@click.argument("dest_dir", type=click.Path(exists=True), default=".")
def main(src_dir: str, dest_dir: str):
    """Simple program that checks if photos in src_dir are correctly imported to dest_dir.
    Currently only Sony cameras and CaptureOne are supported."""
    for ext in exts:
        click.secho(f"Checking {ext} files", fg="blue", err=True)
        src_files = list(Path(src_dir).rglob(f"*.{ext.upper()}"))
        click.secho(f"Found {len(src_files)} {ext} files in {src_dir}", fg="magenta", err=True)

        hashes = process_map(
            hash_file, src_files, max_workers=io_processes, desc="Hashing src files"
        )
        src_entries = {
            file.stem: {
                "path": str(file),
                "hash": hash,
            }
            for file, hash in zip(src_files, hashes)
        }

        cmp_jobs = []
        for f in Path(dest_dir).rglob(f"*.{ext.upper()}", case_sensitive=True):
            entry = src_entries.pop(f.stem, None)
            if entry:
                cmp_jobs.append(
                    {
                        "src": entry["path"],
                        "dest": str(f),
                        "hash": entry["hash"],
                    }
                )

        mismatch_count = 0
        hashes = process_map(
            hash_file,
            [job["dest"] for job in cmp_jobs],
            max_workers=io_processes,
            desc="Hashing dest files",
        )
        for i, job in enumerate(cmp_jobs):
            dest_hash = hashes[i]
            if job["hash"] != dest_hash:
                click.secho(
                    f"!! Hash mismatch: {job['dest']}({dest_hash}) != {job['src']}({job['hash']})",
                    fg="red",
                )
                mismatch_count += 1

        if src_entries:
            for entry in src_entries.values():
                click.secho(
                    f"!! Missing file: {entry['path']}",
                    fg="red",
                )

        color = "green" if mismatch_count == 0 and not src_entries else "red"
        click.secho(
            f"{len(src_entries)} missing, {mismatch_count} mismatches in {ext} files",
            fg=color,
        )


if __name__ == "__main__":
    main()
