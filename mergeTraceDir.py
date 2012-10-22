#!/usr/bin/env python

"""
mergeTraceDir.py

"""

import argparse
import re
import sys

#===============================================================================
# Merge trace and dir file 
#===============================================================================
def merge( traceFile, dirFile ):
  trace = map(lambda x: x.rstrip(), traceFile.readlines())
  dirstate = map(lambda x: x.rstrip(), dirFile.readlines())

  # Function to extract cycle from line in dir file
  dirCyc = lambda x: int(x.split()[0].split(':')[1])

  # Create map of cycle -> list of lines in dir file with that cycle (order preserving)
  cycDirPairs = [ (dirCyc(d),d) for d in dirstate ]
  cycDirMap = {cyc:[] for cyc in set([cdp[0] for cdp in cycDirPairs])}
  for (c,d) in cycDirPairs:
    cycDirMap[c].append(d)

    reCycNum = re.compile("(Cyc) ([0-9]+)")

  last_trace_cycle = -1
  for t in trace:
      
    m = reCycNum.match(t)
    curr_trace_cycle = int(m.group(2)) if m != None else last_trace_cycle
    
    # If we're at the end of a cycle in trace file, add dir file info
    if curr_trace_cycle != last_trace_cycle:
      if last_trace_cycle in cycDirMap:
        for d in cycDirMap[last_trace_cycle]:
          print d
            
    print t
    last_trace_cycle = curr_trace_cycle

#===============================================================================
# Parse command line
#===============================================================================
desc = "Merge dir file into trace file"
post = "Specifying a trace file or dir file take precedence over a filestem"
parser = argparse.ArgumentParser(description=desc,epilog=post)

parser.add_argument("filestem", default="", help="Name of filestem")
parser.add_argument("-t", dest="traceFileName", default="", metavar="T", help="Name of trace file")
parser.add_argument("-d", dest="dirFileName", default="", metavar="D", help="Name of dir file")

args = parser.parse_args(sys.argv[1:])

#===============================================================================
# Main
#===============================================================================
fileStem = args.filestem

if fileStem != "":
  traceFileName = fileStem + ".1.1.trace"
  dirFileName = fileStem + ".dir"

if args.traceFileName != "":
  traceFileName = args.traceFileName

if args.dirFileName != "":
  dirFileName = args.dirFileName

try:
  traceFile = open(traceFileName)
except IOError as e:
  print "Error: File '%s' not found"%traceFileName
  sys.exit(-1)

try:
  dirFile = open(dirFileName)
except IOError as e:
  print >> sys.stderr, "Error: File '%s' not found"%dirFileName
  print traceFile.read()
  traceFile.close()
  sys.exit(0)

merge(traceFile, dirFile)
