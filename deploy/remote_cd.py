#!/usr/bin/python

from deployment import deploy
import os

remote_version = 'download/remote_version'

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
        return out.output

    def _run_and_log(self, cmd):
        deploy.Logger.log(cmd)
        return self._handle_result(self._run_cmd(cmd))

    def _deploy_dmg(self):
        self._run_and_log("hdiutil convert " + os.path.join(self._get_project_path(deploy.CD.PROJECT), Cocoa.TEMPL_DMG) + " -format UDSP -o " + Cocoa.OUTPUT)
        self._run_and_log("hdiutil mount " + Cocoa.SPARSE_OUTPUT)
        self._run_and_log("rm -rf /Volumes/Remote/Remote.app/Contents")
        self._run_and_log("cp -r " + os.path.join(self._get_project_path(deploy.CD.PROJECT), "Contents") + " /Volumes/Remote/Remote.app/")
        self._run_and_log("hdiutil eject /Volumes/Remote")
        self._run_and_log("hdiutil convert " + Cocoa.SPARSE_OUTPUT + " -format UDBZ -o " + Cocoa.DMG_OUTPUT)
        self._run_and_log("rm " + Cocoa.SPARSE_OUTPUT)
        self._run_and_log("scp " + Cocoa.DMG_OUTPUT + " foggyciti@foggyciti.com:")
        self._run_and_log("rm " + Cocoa.DMG_OUTPUT)
        self._run_and_log("ssh foggyciti@foggyciti.com './trampoline.sh Remote.dmg'")

    def _zip_to_download(self, filename):
       self._run_and_log("zip -q -r %s.zip %s" % (filename, filename))
       self._run_and_log("scp %s.zip foggyciti@foggyciti.com:" % (filename))
       self._run_and_log("ssh foggyciti@foggyciti.com './trampoline.sh %s.zip'" % (filename))
       self._run_and_log("rm %s.zip" % (filename))

    def _deploy_updates(self):
        cwd = os.getcwd()
        os.chdir(os.path.join(self._get_project_path(deploy.CD.PROJECT), "Contents/Resources"))

        self._zip_to_download("daemon.app")
        self._zip_to_download("helper.app")

        os.chdir(cwd)
 
    def _incr_version(self):
        version = self._run_and_log("ssh foggyciti@foggyciti.com 'cat %s'" % (remote_version))
        if len(version) == 0:
            version = "0"
        self._run_and_log("ssh foggyciti@foggyciti.com 'echo %d > %s'" % (int(version) + 1, remote_version))

    def _deploy(self):
        self._deploy_dmg()
        self._deploy_updates()
        self._incr_version()
        
deploy.main(Cocoa())
