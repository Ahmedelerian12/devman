# Linux Cheat Sheet

## Goal

Learn where you are, what is running, what is listening, and why a request works
or fails.

## Steps

1. Map the machine: `pwd`, `whoami`, `uname -a`, `df -h`, `free -h`, `echo $PATH`
2. Inspect processes: `ps aux | head`
3. Inspect ports: `ss -tulpn` or `netstat -tulpn`
4. Test HTTP: `curl -I https://example.com`
5. Inspect DNS: `getent hosts example.com` or `dig example.com`
6. Practice permissions: `touch test.txt && chmod 600 test.txt && ls -l test.txt`
7. Write what happened in `incident-note.md`

## Done Looks Like

`devman learn validate linux .` passes, and your note explains symptom, checks,
cause, fix, and prevention.
