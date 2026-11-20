# README

## Secrets
The project uses `fnox` for secret management, with `age` as the provider. The hosts must have either:
- ~/.config/fnox/age.txt
- `FNOX_AGE_KEY` defined as an `env` var with the identity. This identity starting with `AGE-SECRET-*` is only usable for decryption.

Prefer `FNOX_AGE_KEY` in remote sandboxes.
