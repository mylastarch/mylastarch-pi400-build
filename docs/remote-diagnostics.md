# Remote diagnostics

The development computer uses a project-specific SSH key stored under the
Git-ignored `secrets/` directory to connect to the Pi as `alarm`.

This key does not provide passwordless root access. It is intended for status
checks, report collection, and transferring reviewed scripts. Privileged
changes continue to require explicit action on the Pi unless that policy is
changed deliberately later.

To revoke access on the Pi, remove the line ending in
`mylastarch-pi400-diagnostics` from `/home/alarm/.ssh/authorized_keys`.
