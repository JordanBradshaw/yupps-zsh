function rmempty() {
  find . -type f -empty -delete
  find . -type d -empty -delete
}
