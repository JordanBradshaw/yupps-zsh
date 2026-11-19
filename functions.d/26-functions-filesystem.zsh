#!/bin/zsh
##? dus - sizes of the entries in the current directory, smallest first
function dus() {
  du -sh * 2>/dev/null | sort -h
}
