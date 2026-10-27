# Rhino Blueprint — AI Guide

Use this file to teach AI assistants how to generate valid YAML blueprint files.

## Quick Start

1. Create `_roles.yaml` in `.rhino/blueprints/` with your role definitions
2. Create `{model_slug}.yaml` for each model
3. Run `rails rhino:blueprint` to generate all files

## Roles Format

```yaml
roles:
  owner:
    name: Owner
    description: "Full access"
  viewer:
    name: Viewer
    description: "Read-only"
```

## Model Format

```yaml
model: Contract
slug: contracts

options:
  belongs_to_organization: true
  soft_deletes: true

columns:
  title:
    type: string
    filterable: true

permissions:
  owner:
    actions: [index, show, store, update, destroy]
    show_fields: "*"
    create_fields: "*"
    update_fields: "*"
```

## Valid Column Types
string, text, integer, bigInteger, boolean, date, datetime, timestamp, decimal, float, json, uuid, foreignId

## Valid Actions
index, show, store, update, destroy, trashed, restore, forceDelete
