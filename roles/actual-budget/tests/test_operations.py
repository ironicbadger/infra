import importlib.util
import json
import pathlib
import tempfile
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('operate',pathlib.Path(__file__).parents[1]/'files/operate.py')
op=importlib.util.module_from_spec(spec); spec.loader.exec_module(op)

class BackupFailureTests(unittest.TestCase):
    def test_encryption_start_failure_restarts_server_and_keeps_previous_backup(self):
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d)
            old=root/'previous.tar.gz.age'; old.write_bytes(b'existing')
            calls=[]
            def fake_run(*args,**kwargs):
                calls.append(args)
                if args[:2]==('docker','inspect'):
                    return json.dumps([{'Config':{'Image':op.IMAGE,'Labels':{'com.docker.compose.project':'root','com.docker.compose.service':'actual-budget'}}}]).encode()
                if args[:2]==('docker','compose'): return b'{"services":{"actual-budget":{}}}'
                return b''
            with patch.object(op,'BACKUPS',root), patch.object(op,'run',side_effect=fake_run), patch.object(op.subprocess,'Popen',side_effect=OSError('private error')):
                with self.assertRaises(OSError): op.backup()
            self.assertIn(('docker','start','actual-budget'),calls)
            self.assertEqual(old.read_bytes(),b'existing')
            self.assertFalse(list(root.glob('*.partial')))

if __name__=='__main__': unittest.main()
