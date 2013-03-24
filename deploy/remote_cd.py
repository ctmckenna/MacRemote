#!/usr/bin/python

from deployment import deploy
import os

class Cocoa(deploy.CD):
    deploy.CD.PROJECT = 'Remote.app'
    TEMPL_DMG = '../template.dmg'          # relative to project
    OUTPUT = 'Remote'
    SPARSE_OUTPUT = OUTPUT + ".sparseimage"
    DMG_OUTPUT = OUTPUT + ".dmg"

    def _handle_result(self, out):
        deploy.Logger.log(out.output)
        if out.returncode != 0:
            raise deploy.DeployFail()

    def _run_and_log(self, cmd):
        deploy.Logger.log(cmd)
        self._handle_result(self._run_cmd(cmd))

    def _deploy(self):
        self._run_and_log("hdiutil convert " + os.path.join(self._project_path(), Cocoa.TEMPL_DMG) + " -format UDSP -o " + Cocoa.OUTPUT)
        self._run_and_log("hdiutil mount " + Cocoa.SPARSE_OUTPUT)
        self._run_and_log("rm -rf /Volumes/Remote/Remote.app/Contents")
        self._run_and_log("cp -r " + os.path.join(self._project_path(), "Contents") + " /Volumes/Remote/Remote.app/")
        self._run_and_log("hdiutil eject /Volumes/Remote")
        self._run_and_log("hdiutil convert " + Cocoa.SPARSE_OUTPUT + " -format UDBZ -o " + Cocoa.DMG_OUTPUT)
        self._run_and_log("rm " + Cocoa.SPARSE_OUTPUT)
        self._run_and_log("scp " + Cocoa.DMG_OUTPUT + " foggyciti@foggyciti.com:")
        self._run_and_log("rm " + Cocoa.DMG_OUTPUT)
        self._run_and_log("ssh foggyciti@foggyciti.com './trampoline.sh Remote.dmg'")

deploy.main(Cocoa())
