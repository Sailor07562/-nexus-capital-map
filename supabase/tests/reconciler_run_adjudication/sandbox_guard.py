"""Shared fail-closed guards; never rely on Python assertions for isolation."""
import re


def validate_container(info, container_name):
    if not re.fullmatch(r'nexus-ct-adjudication-[A-Za-z0-9-]+', container_name):
        raise RuntimeError('Unexpected sandbox container name')
    host = info.get('HostConfig', {})
    requirements = [
        (info.get('State', {}).get('Running') is True, 'Sandbox is not running'),
        (host.get('NetworkMode') == 'none', 'Sandbox network must be none'),
        (not host.get('Binds'), 'Sandbox must not use host binds'),
        (not host.get('PortBindings'), 'Sandbox must not publish ports'),
        (host.get('ReadonlyRootfs') is True, 'Sandbox root must be read-only'),
        ('/var/lib/postgresql/data' in host.get('Tmpfs', {}), 'Sandbox PGDATA must be tmpfs'),
        (all(m.get('Type') == 'tmpfs' for m in info.get('Mounts', [])), 'Sandbox must not use persistent mounts'),
    ]
    for passed, message in requirements:
        if not passed:
            raise RuntimeError(message)


def validate_version(server_version_num):
    if not 170000 <= int(server_version_num) < 180000:
        raise RuntimeError('Sandbox must run native PostgreSQL 17')
