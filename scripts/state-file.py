#!/usr/bin/env python3
"""Read or write the pet save through one validated descriptor.

Opens with O_NOFOLLOW | O_NONBLOCK, requires a regular file, and refuses
anything larger than the cap so omarchy-shell never loads a swapped-in blob.
"""
import os
import stat
import sys

READ_FLAGS = os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK
WRITE_FLAGS = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_NONBLOCK


def fail(code=1):
    sys.exit(code)


def read_file(path, cap):
    try:
        fd = os.open(path, READ_FLAGS)
    except FileNotFoundError:
        fail(2)
    except OSError:
        fail(1)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_size > cap:
            fail(1)
        data = os.read(fd, cap + 1)
        if len(data) > cap:
            fail(1)
    finally:
        os.close(fd)
    sys.stdout.buffer.write(data)


def write_file(path, cap):
    data = sys.stdin.buffer.read(cap + 1)
    if len(data) > cap:
        fail(1)
    folder = os.path.dirname(path) or "."
    os.makedirs(folder, mode=0o755, exist_ok=True)
    tmp = path + ".tmp"
    try:
        os.unlink(tmp)
    except FileNotFoundError:
        pass
    except OSError:
        fail(1)
    fd = os.open(tmp, WRITE_FLAGS, 0o644)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode):
            fail(1)
        view = memoryview(data)
        while view:
            n = os.write(fd, view)
            if n <= 0:
                fail(1)
            view = view[n:]
        os.fsync(fd)
    finally:
        os.close(fd)
    try:
        os.replace(tmp, path)
    except OSError:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        fail(1)


def main():
    if len(sys.argv) != 4:
        fail(1)
    op, path, cap_s = sys.argv[1], sys.argv[2], sys.argv[3]
    try:
        cap = int(cap_s)
    except ValueError:
        fail(1)
    if cap <= 0 or not path:
        fail(1)
    if op == "read":
        read_file(path, cap)
    elif op == "write":
        write_file(path, cap)
    else:
        fail(1)


if __name__ == "__main__":
    main()
