#!/usr/bin/env -S just --justfile

set lazy
set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

# Bootstrap Recipes
[group: 'Bootstrap']
mod? bootstrap ".justfiles/bootstrap"

# Kube Recipes
[group: 'Kube']
mod? kube ".justfiles/kubernetes"

# Talos Recipes
[group: 'Talos']
mod? talos ".justfiles/talos"

# VolSync Recipes
[group: 'VolSync']
mod? volsync ".justfiles/volsync"

# 1Password Recipes
[group: '1Password']
mod? op ".justfiles/onepassword"

[private]
default:
    just -l --list-submodules

[private]
log lvl msg *args:
    gum log -t rfc3339 -s -l "{{ lvl }}" "{{ msg }}" {{ args }}

[private]
template file *args:
    minijinja-cli "{{ file }}" {{ args }} | op inject
