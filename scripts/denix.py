from functools import partial
import click
import shutil
import os
from typing import Callable
import subprocess


def checkPaths(paths: list[str], f_err: Callable[[str], str], revert: bool = False):
    def f(x: bool):
        return not x if revert else x

    for path in paths:
        if f(os.path.exists(path)):
            raise click.ClickException(f_err(path))


def copy2_and_set_writable(src: str, dst: str):
    shutil.copy2(src, dst)
    os.chmod(dst, os.stat(dst).st_mode | 0o220)


def do(path: str):
    denix_path = f".{path}.denix"
    bak_path = f".{path}.denix.bak"
    # This is a simple script, so no need to deal with TOCTOU
    checkPaths(
        [denix_path, bak_path],
        lambda p: f"File {p} already exists. Please revert changes first.",
    )

    f_copy = (
        copy2_and_set_writable
        if os.path.isfile(path)
        else partial(shutil.copytree, copy_function=copy2_and_set_writable)
    )
    click.echo(f"Copying {path} to {denix_path}...", err=True)
    f_copy(path, denix_path)
    click.echo(f"Backing up {path} to {bak_path}...", err=True)
    shutil.move(path, bak_path)
    click.echo(f"Linking {denix_path} to {path}...", err=True)
    os.symlink(denix_path, path)


def do_revert(path: str):
    denix_path = f".{path}.denix"
    bak_path = f".{path}.denix.bak"
    checkPaths(
        [denix_path, bak_path],
        lambda p: f"File {p} does not exist. Are you sure this path was denixed?",
        revert=True,
    )

    click.echo(f"Comparing {denix_path} and {bak_path}...", err=True)
    result = subprocess.run(
        ["diff", "-rq", bak_path, denix_path], capture_output=True, text=True
    )
    if result.returncode != 0:
        click.echo("Differences found between files:\n", err=True)
        subprocess.run(["diff", "--color=auto", "-ru", bak_path, denix_path])
        click.confirm("\nAre you sure you want to revert these changes?", abort=True)

    click.echo(f"Removing symlink {path}...", err=True)
    os.remove(path)
    click.echo(f"Restoring {bak_path} to {path}...", err=True)
    shutil.move(bak_path, path)
    click.echo(f"Removing {denix_path}...", err=True)
    f_del = os.remove if os.path.isfile(denix_path) else shutil.rmtree
    f_del(denix_path)


@click.command()
@click.argument("path", type=click.Path(exists=True))
@click.option("-r", "--revert", is_flag=True, help="revert changes made")
def main(path: str, revert: bool):
    path = path.rstrip("/")
    if revert:
        do_revert(path)
    else:
        do(path)


if __name__ == "__main__":
    main()
