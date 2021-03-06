#!/usr/bin/python
# Copyright (c) 2015 Connectal Project
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
#

import os, sys
import glob
import argparse
import re
import bsvpreprocess

def getBsvPackages(bluespecdir):
    """BLUESPECDIR is expected to be the path to the bluespec distribution.
    The function GETBSVPACKAGES returns a list of all
    the packages in the prelude library of this distribution.
    """
    pkgs = []
    for f in glob.glob('%s/Prelude/*.bo' % bluespecdir):
        pkgs.append(os.path.splitext(os.path.basename(f))[0])
    return pkgs

def bsvDependencies(bsvfile, allBsv=False, bluespecdir=None, argbsvpath=[], bsvdefine=[]):
    """Return the list of dependencies
    [(NAME,BSVFILENAME,PACKAGES,INCLUDES,SYNTHESIZEDMODULES)] of
    BSVFILE, adding the list BSVPATH to the directories to explore for
    dependencies.

    The boolean ALLBSV will generate entries for all
    BSV files on path.

    The string BLUESPECDIR will add the Prelude of
    Bsv in packages.

    The BSVDEFINE argument is passed to the
    preprocessor.

    """
    bsvpath = []
    for p in argbsvpath:
        ps = p.split(':')
        bsvpath.extend(ps)
    bsvpackages = getBsvPackages(bluespecdir)
    if allBsv:
        for d in bsvpath:
            for bsvfilename in glob.glob('%s/*.bsv' % d):
                if bsvfilename not in bsvfile:
                    bsvfile.append(bsvfilename)
    abspaths = {}
    for f in bsvfile:
        abspaths[os.path.basename(f)] = f
    for d in bsvpath:
        for f in glob.glob('%s/*' % d):
            abspaths[os.path.basename(f)] = f
    generated = []
    for bsvfilename in bsvfile:
        vf = open(bsvfilename, 'r')
        basename = os.path.basename(bsvfilename)
        (name, ext) = os.path.splitext(basename)
        source = vf.read()
        preprocess = bsvpreprocess.preprocess(bsvfilename, source, bsvdefine, bsvpath)
        packages = []
        includes = []
        synthesizedModules = []
        synthesize = False
        for line in preprocess.split('\n'):
            m = re.match('//`include "([^\"]+)"', line)
            m1 = re.match('//`include(.*)', line)
            if m:
                iname = m.group(1)
                if iname in abspaths:
                    iname = abspaths[iname]
                else:
                    iname = 'obj/%s' % iname
                includes.append(iname)
            elif m1:
                sys.stderr.write('bsvdepend %s: unhandled `include %s\n' % (bsvfilename, m1.group(1)))

            if re.match('^//', line):
                continue
            m = re.match('import ([A-Za-z0-9_]+)\w*', line)
            if m:
                pkg = m.group(1)
                if pkg not in packages and pkg not in bsvpackages:
                    packages.append(pkg)
            if synthesize:
                m = re.match('\s*module\s+([A-Za-z0-9_]+)', line)
                if m:
                    synthesizedModules.append(m.group(1))
                else:
                    sys.stderr.write('bsvdepend: in %s expecting module: %s\n' % (bsvfilename, line))
            synth = line.find('(* synthesize *)')
            attr = line.find('(* ')
            if synth >= 0:
                synthesize = True
            elif attr >= 0:
                pass # no change to synthesize
            else:
                synthesize = False
            pass
        generated.append((bsvfilename,packages,includes,synthesizedModules))
        vf.close()
    return (generated,bsvpath)
