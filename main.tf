locals {
  name        = "${var.cluster.name}-bootstrap"
  description = "${var.cluster.name} Bootstrap"

  force_trigger = var.force ? timestamp() : ""

  build_path = "${path.module}/.build"
  build_zip  = "${path.module}/bootstrap.zip"

  source_path = "${path.module}/source"
  source_hash = base64sha256(join("", concat([local.force_trigger], [
    for file in sort(fileset(local.source_path, "**/*")) : filesha256("${local.source_path}/${file}")
  ])))
}

action "local_command" "build" {
  config {
    working_directory = path.module

    command   = "sh"
    arguments = ["scripts/build.sh"]
  }
}

resource "terraform_data" "build" {
  triggers_replace = {
    source_hash   = local.source_hash
    force_trigger = local.force_trigger
  }

  lifecycle {
    action_trigger {
      events     = [before_create]
      actions    = [action.local_command.build]
      on_failure = taint
    }
  }
}

resource "google_project_service" "this" {
  for_each = toset([
    "iam.googleapis.com",
    "storage.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "run.googleapis.com"
  ])

  project = data.google_client_config.current.project
  service = each.key
}

resource "google_service_account" "this" {
  account_id   = local.name
  display_name = local.name
  description  = local.description

  depends_on = [google_project_service.this["iam.googleapis.com"]]
}

resource "google_project_iam_member" "container_admin" {
  project = data.google_client_config.current.project
  member  = "serviceAccount:${google_service_account.this.email}"
  role    = "roles/container.admin"

  depends_on = [google_project_service.this["iam.googleapis.com"]]
}

resource "google_project_iam_member" "log_writer" {
  project = data.google_client_config.current.project
  member  = "serviceAccount:${google_service_account.this.email}"
  role    = "roles/logging.logWriter"

  depends_on = [google_project_service.this["iam.googleapis.com"]]
}

resource "google_storage_bucket" "this" {
  name     = local.name
  location = data.google_client_config.current.region

  force_destroy               = true
  uniform_bucket_level_access = true

  labels = var.labels

  depends_on = [google_project_service.this["storage.googleapis.com"]]
}

resource "google_storage_bucket_object" "this" {
  name   = "${local.name}.zip"
  bucket = google_storage_bucket.this.name

  source         = local.build_zip
  source_md5hash = local.source_hash

  depends_on = [terraform_data.build]
}

resource "google_cloudfunctions2_function" "this" {
  name        = local.name
  description = local.description
  location    = data.google_client_config.current.region

  build_config {
    runtime     = "python314"
    entry_point = "handler"
    environment_variables = {
      SOURCE_HASH = local.source_hash
    }

    source {
      storage_source {
        bucket = google_storage_bucket.this.name
        object = google_storage_bucket_object.this.name
      }
    }
  }

  service_config {
    available_memory = "1Gi"
    timeout_seconds  = 900

    service_account_email = google_service_account.this.email

    direct_vpc_egress = "VPC_EGRESS_ALL_TRAFFIC"
    direct_vpc_network_interface {
      network    = var.cluster.network
      subnetwork = var.cluster.subnetwork
    }

    environment_variables = {
      CLUSTER = var.cluster.name
    }
  }

  labels = var.labels

  depends_on = [
    google_storage_bucket_object.this,
    google_project_service.this["run.googleapis.com"],
    google_project_service.this["cloudfunctions.googleapis.com"],
    google_project_service.this["cloudbuild.googleapis.com"],
  ]
}

action "local_command" "invoke" {
  config {
    working_directory = path.module

    command = "sh"
    arguments = ["-c", <<EOT
        set -eu
        OUTPUT="$(mktemp)"
        
        gcloud functions call ${google_cloudfunctions2_function.this.name} --gen2 \
          --project ${data.google_client_config.current.project} \
          --region ${data.google_client_config.current.region} \
          --data '${jsonencode({ charts = var.charts })}' \
          --format json > "$OUTPUT"

        STATUS="$(jq -r 'fromjson | .status' "$OUTPUT")"
        test "$STATUS" = "Provisioning successful"
      EOT
    ]
  }
}

resource "terraform_data" "invoke" {
  triggers_replace = {
    cluster_id    = var.cluster.id
    source_hash   = local.source_hash
    force_trigger = local.force_trigger
    charts_hash   = sha256(jsonencode(var.charts))
  }

  depends_on = [
    terraform_data.build,
    google_cloudfunctions2_function.this,
  ]

  lifecycle {
    action_trigger {
      events     = [after_create]
      actions    = [action.local_command.invoke]
      on_failure = taint
    }
  }
}

resource "time_sleep" "this" {
  count           = var.sleep != null ? 1 : 0
  create_duration = var.sleep
  depends_on      = [terraform_data.invoke]
}
