# Stage 4: projects

Reference: `terraform-example-foundation/4-projects` (business-unit folders, standard projects attached to the Shared VPC,
per-application infrastructure pipelines). One root per environment, state prefix `4-projects/<env>`, runs as `sa-terraform-projects`.

## Creates
- One service project per application per environment, attached to that environment's Shared VPC host project.
- The permissions each application's team and `sa-terraform-workloads` need on its projects (stage 5 gets them here, not at organization level).
- Project names follow `<empresa>-<entorno>-<dominio>-<recurso>` and carry the mandatory labels.

## Notes
- Request a project-quota increase for `sa-terraform-projects` early: the example recommends asking for 50 extra projects after bootstrap.
- Runbook to write: "alta de un nuevo proyecto de aplicación" (adding an application means one entry in a map, then a PR).
