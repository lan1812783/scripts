# Various utilities

## Usages

- Git hook utilities: `git-hooks/setup.sh -h`
- JWT key generation: `jwt/jwt_kegen.sh -h`
- Flame Graph rendering: `flamegraph/renderFlameGraph.sh -h`

## Templates

### Steps:

- Copy the chosen script
- Define the definitions
  ```bash
  ##### Definitions #####
  ...
  ##### End definitions #####
  ```
- Use the script

### Usages:

- Notify before a command runs and after it finishes: `cmd_notif.sh` (suitable for crontab)
