# README

# Uh Oh
## Why
Tracking network problems is hard when everyone has a laptop.  
We need active reports from employees to identify trouble spots as they arise, but we also need those reports to be easy to submit and to provide useful information.

## What
Uh-Oh is a one click application which gathers some info about the computer it runs on, the access point its connected, and the quality of the wifi connection.

## How
Computer information is gathered through some bash-fu, then cut together and submitted to our Helpdesk via curl.

This ruby script is packed into an app via Automator.  To do that : 
Run Automator > New > Application
Choose Run Shell Script
Shell = usr/bin/ruby
Pass Input = to stdin

![automator](img)

## TODO
replace grep and awk and print with something more ruby-esq