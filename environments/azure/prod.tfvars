# Nonsecret LSK Azure prod profile. Per-tenant location and credentials are environment inputs.
environment="prod"
min_replicas=2
max_replicas=8
pg_sku="GP_Standard_D2s_v3"
enable_zone_redundancy=true
