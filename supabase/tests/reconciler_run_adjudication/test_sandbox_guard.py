"""Guard tests also run under python -O; no database connections or mutations."""
from copy import deepcopy
import unittest
from sandbox_guard import validate_container, validate_version


class SandboxGuardTests(unittest.TestCase):
    def setUp(self):
        self.name = 'nexus-ct-adjudication-synthetic'
        self.info = {'State': {'Running': True}, 'HostConfig': {
            'NetworkMode': 'none', 'Binds': None, 'PortBindings': {},
            'ReadonlyRootfs': True, 'Tmpfs': {'/var/lib/postgresql/data': 'size=512m'}}, 'Mounts': []}

    def test_accept_isolated_container(self):
        validate_container(self.info, self.name)

    def test_reject_unexpected_name(self):
        with self.assertRaises(RuntimeError):
            validate_container(self.info, 'production')

    def test_reject_stopped_container(self):
        self.info['State']['Running'] = False
        with self.assertRaises(RuntimeError):
            validate_container(self.info, self.name)

    def test_reject_unsafe_container_properties(self):
        bad = [('NetworkMode','bridge'), ('Binds',['host:data']),
               ('PortBindings',{'5432/tcp':[{'HostPort':'5432'}]}),
               ('ReadonlyRootfs',False), ('Tmpfs',{})]
        for key, value in bad:
            with self.subTest(property=key):
                info = deepcopy(self.info)
                info['HostConfig'][key] = value
                with self.assertRaises(RuntimeError):
                    validate_container(info, self.name)

    def test_reject_persistent_volume(self):
        self.info['Mounts'] = [{'Type':'volume'}]
        with self.assertRaises(RuntimeError):
            validate_container(self.info, self.name)

    def test_accept_native_pg17(self):
        validate_version('170011')

    def test_reject_other_postgres_versions(self):
        for value in ('160010','180001'):
            with self.subTest(version=value), self.assertRaises(RuntimeError):
                validate_version(value)


if __name__ == '__main__':
    unittest.main()
